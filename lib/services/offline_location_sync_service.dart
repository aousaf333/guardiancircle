import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardiancircle/services/connectivity_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';

/// Status of the offline location synchronization, exposed to the UI so the
/// map screen can reflect it in the connectivity pill.
enum OfflineLocationSyncStatus { idle, synced }

/// Tracks GPS locations captured while offline in a Hive queue and uploads
/// them to Supabase in chronological order once internet connectivity is
/// restored.
///
/// Mirrors the `EmergencyAlertService.startOfflineSync()` pattern: a shared
/// [ConnectivityService] plus static subscriptions/guards so it is safe to
/// start once at app startup.
class OfflineLocationSyncService {
  static final ConnectivityService _sharedConnectivity = ConnectivityService();
  static bool _connectivityInitialized = false;

  static StreamSubscription<bool>? _syncSubscription;
  static bool _wasOnline = false;
  static bool _syncRunning = false;
  static bool _isOffline = false;

  static const String _boxName = 'offline_location_queue';

  static const double _minDistanceMeters = 25;
  static const Duration _minTimeBetweenUpdates = Duration(minutes: 2);

  static double _lastDrainHistoryLat = 0;
  static double _lastDrainHistoryLng = 0;
  static DateTime? _lastDrainHistoryUpdate;

  static Timer? _syncedResetTimer;

  /// Reflects the current offline-location sync status for UI display.
  ///
  /// Starts as [OfflineLocationSyncStatus.idle], becomes
  /// [OfflineLocationSyncStatus.synced] briefly once the queue has been fully
  /// uploaded, then resets back to idle.
  static final ValueNotifier<OfflineLocationSyncStatus> statusNotifier =
      ValueNotifier(OfflineLocationSyncStatus.idle);

  /// Whether the device is currently offline according to the shared
  /// [ConnectivityService]. Used by live location tracking to decide whether
  /// to queue positions instead of uploading them.
  static bool get isCurrentlyOffline => _isOffline;

  /// Starts listening for connectivity changes and automatically uploads any
  /// queued offline locations once internet is restored.
  ///
  /// Safe to call more than once; subsequent calls are no-ops.
  static Future<void> startOfflineSync() async {
    if (_syncSubscription != null) return;

    if (!_connectivityInitialized) {
      await _sharedConnectivity.initialize();
      _connectivityInitialized = true;
    }

    _isOffline = !_sharedConnectivity.isCurrentlyOnline;
    _wasOnline = _sharedConnectivity.isCurrentlyOnline;
    _syncSubscription =
        _sharedConnectivity.isOnline.listen(_onConnectivityChanged);
    print('[OfflineLocation] Listening for connectivity changes');
  }

  static void _onConnectivityChanged(bool online) {
    if (online) {
      _isOffline = false;
      if (!_wasOnline) {
        _syncQueuedLocations();
      }
    } else {
      _isOffline = true;
      print('[OfflineLocation] Offline');
    }
    _wasOnline = online;
  }

  /// Queues a GPS [position] captured while offline so it can be uploaded once
  /// internet connectivity is restored.
  static Future<void> enqueueLocation(Position position) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;

      final box = LocalStorageService.instance.box(_boxName);
      if (box == null) {
        print('[OfflineLocation] offline_location_queue box not available');
        return;
      }

      await box.add({
        'userId': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      print('[OfflineLocation] Added location to queue');
      print('[OfflineLocation] Queue size: ${box.length}');
    } catch (e) {
      print('[OfflineLocation] Failed to queue location: $e');
    }
  }

  static Future<void> _syncQueuedLocations() async {
    if (_syncRunning) return;
    _syncRunning = true;

    try {
      print('[OfflineLocation] Internet restored');

      final box = LocalStorageService.instance.box(_boxName);
      if (box == null) return;
      if (box.isEmpty) return;

      print('[OfflineLocation] Found ${box.length} queued locations');

      final entries = box.toMap().entries.toList()
        ..sort((a, b) {
          final ta = (a.value['timestamp'] as String?) ?? '';
          final tb = (b.value['timestamp'] as String?) ?? '';
          return ta.compareTo(tb);
        });

      for (final entry in entries) {
        print('[OfflineLocation] Uploading queued location');
        try {
          final uploaded = await _uploadQueuedLocation(entry.value);
          if (uploaded) {
            print('[OfflineLocation] Upload successful');
            await box.delete(entry.key);
            print('[OfflineLocation] Removed from queue');
          } else {
            print('[OfflineLocation] Upload failed');
            print('[OfflineLocation] Keeping location in queue');
            print('[OfflineLocation] Will retry automatically');
            return;
          }
        } catch (e) {
          print('[OfflineLocation] Upload failed');
          print('[OfflineLocation] Keeping location in queue');
          print('[OfflineLocation] Will retry automatically');
          return;
        }
      }

      if (box.isEmpty) {
        print('[OfflineLocation] Queue empty');
        _notifySynced();
      }
    } finally {
      _syncRunning = false;
    }
  }

  static Future<bool> _uploadQueuedLocation(dynamic raw) async {
    final value = raw as Map;
    final userId = value['userId'] as String?;
    if (userId == null || userId.isEmpty) return false;

    final latitude = (value['latitude'] as num).toDouble();
    final longitude = (value['longitude'] as num).toDouble();
    final accuracy = (value['accuracy'] as num?)?.toDouble() ?? 0;
    final speed = (value['speed'] as num?)?.toDouble() ?? 0;
    final heading = (value['heading'] as num?)?.toDouble() ?? 0;
    final recordedAt = value['timestamp'] as String?;

    await SupabaseService.client.from('user_locations').upsert(
      {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );

    await _saveQueuedHistory(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      recordedAt: recordedAt,
    );

    return true;
  }

  static Future<void> _saveQueuedHistory({
    required String userId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required double heading,
    String? recordedAt,
  }) async {
    final now = DateTime.now();
    final distance = Geolocator.distanceBetween(
      _lastDrainHistoryLat,
      _lastDrainHistoryLng,
      latitude,
      longitude,
    );
    final timeSinceLast = _lastDrainHistoryUpdate != null
        ? now.difference(_lastDrainHistoryUpdate!)
        : _minTimeBetweenUpdates;
    final shouldSaveHistory =
        distance >= _minDistanceMeters ||
            timeSinceLast >= _minTimeBetweenUpdates;
    if (!shouldSaveHistory) return;

    _lastDrainHistoryLat = latitude;
    _lastDrainHistoryLng = longitude;
    _lastDrainHistoryUpdate = now;

    print('[OfflineLocation] History Saved: userId=$userId, '
        'lat=$latitude, lng=$longitude');
    await SupabaseService.client.from('location_history').insert({
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'recorded_at': recordedAt ?? now.toUtc().toIso8601String(),
    });
  }

  static void _notifySynced() {
    print('[OfflineLocation] Showing success notification');
    print('[OfflineLocation] Location Synced: All offline location updates '
        'have been synchronized successfully');
    statusNotifier.value = OfflineLocationSyncStatus.synced;
    _syncedResetTimer?.cancel();
    _syncedResetTimer = Timer(const Duration(seconds: 4), () {
      statusNotifier.value = OfflineLocationSyncStatus.idle;
    });
  }
}
