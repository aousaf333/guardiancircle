import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:guardiancircle/models/emergency_alert_model.dart';
import 'package:guardiancircle/services/alert_cache_service.dart';
import 'package:guardiancircle/services/connectivity_service.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';
import 'package:guardiancircle/services/notification_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyAlertService {
  final SupabaseClient _client;
  RealtimeChannel? _alertsChannel;
  Timer? _locationUpdateTimer;
  Timer? _debounceTimer;
  final Set<String> _processedAlertIds = {};
  final Set<String> _dismissedAlertIds = {};

  EmergencyAlertService(this._client);

  factory EmergencyAlertService.defaultClient() =>
      EmergencyAlertService(SupabaseService.client);

  SupabaseClient get _supabase => _client;

  // ---------------------------------------------------------------------------
  // Connectivity + offline cache helpers
  // ---------------------------------------------------------------------------
  static final ConnectivityService _sharedConnectivity = ConnectivityService();
  static bool _connectivityInitialized = false;

  static StreamSubscription<bool>? _offlineSyncSubscription;
  static bool _offlineSyncWasOnline = false;
  static bool _offlineSyncRunning = false;

  /// Starts listening for connectivity changes and automatically uploads any
  /// queued offline SOS alerts once internet is restored.
  ///
  /// Safe to call more than once; subsequent calls are no-ops.
  static Future<void> startOfflineSync() async {
    if (_offlineSyncSubscription != null) return;

    if (!_connectivityInitialized) {
      await _sharedConnectivity.initialize();
      _connectivityInitialized = true;
    }

    _offlineSyncWasOnline = _sharedConnectivity.isCurrentlyOnline;
    _offlineSyncSubscription =
        _sharedConnectivity.isOnline.listen(_onConnectivityChanged);
    print('[OfflineSync] Listening for connectivity changes');
  }

  static void _onConnectivityChanged(bool online) {
    if (online && !_offlineSyncWasOnline) {
      _syncQueuedSosAlerts();
    }
    _offlineSyncWasOnline = online;
  }

  static Future<void> _syncQueuedSosAlerts() async {
    if (_offlineSyncRunning) return;
    _offlineSyncRunning = true;

    try {
      print('[OfflineSync] Internet restored');

      final box = LocalStorageService.instance.box('offline_queue');
      if (box == null) return;

      final sosEntries = <dynamic, Map<dynamic, dynamic>>{};
      box.toMap().forEach((key, value) {
        if (value is Map && value['type'] == 'sos') {
          sosEntries[key] = value;
        }
      });

      print('[OfflineSync] Found ${sosEntries.length} queued SOS alerts');
      if (sosEntries.isEmpty) return;

      final service = EmergencyAlertService.defaultClient();

      var allUploaded = true;

      for (final entry in sosEntries.entries) {
        print('[OfflineSync] Uploading SOS...');
        try {
          final latitude = (entry.value['latitude'] as num).toDouble();
          final longitude = (entry.value['longitude'] as num).toDouble();

          final alert = await service.createSosAlert(
            latitude: latitude,
            longitude: longitude,
          );

          if (alert != null) {
            print('[OfflineSync] Upload successful');
            await box.delete(entry.key);
            print('[OfflineSync] Removed from queue');
          } else {
            allUploaded = false;
            print('[OfflineSync] Upload failed');
            print('[OfflineSync] Keeping SOS in queue');
            print('[OfflineSync] Will retry automatically');
          }
        } catch (e) {
          allUploaded = false;
          print('[OfflineSync] Upload failed');
          print('[OfflineSync] Keeping SOS in queue');
          print('[OfflineSync] Will retry automatically');
        }
      }

      final remainingSos = box.values.where(
        (value) => value is Map && value['type'] == 'sos',
      );
      if (remainingSos.isEmpty) {
        print('[OfflineSync] Queue empty');
      }

      if (allUploaded) {
        print('[OfflineSync] Queue upload completed');
        await NotificationService.showOfflineSosSuccessNotification();
        print(
            '[OfflineSync] Offline SOS successfully sent after internet restoration');
      }
    } finally {
      _offlineSyncRunning = false;
    }
  }

  Future<bool> _isOnline() async {
    if (!_connectivityInitialized) {
      await _sharedConnectivity.initialize();
      _connectivityInitialized = true;
    }
    return _sharedConnectivity.isCurrentlyOnline;
  }

  /// Public connectivity check for callers that need to reflect offline state
  /// in their UI without owning a [ConnectivityService].
  Future<bool> isOnline() => _isOnline();

  Future<void> _queueSosOffline({
    required String userId,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    try {
      final box = LocalStorageService.instance.box('offline_queue');
      if (box == null) {
        print('[SOS] offline_queue box not available');
        return;
      }
      await box.add({
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'message': message,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'type': 'sos',
      });
      print('[SOS] Added to offline queue');
      print('[SOS] Queue size: ${box.length}');
    } catch (e) {
      print('[SOS] Failed to queue offline SOS: $e');
    }
  }

  Future<List<EmergencyAlertWithSender>> _loadCachedAlerts() async {
    final cached = AlertCacheService.instance.loadCachedAlerts();
    return cached
        .map((alert) => EmergencyAlertWithSender(
              alert: alert,
              senderName: 'Unknown',
              senderPhotoUrl: null,
            ))
        .toList();
  }

  Future<EmergencyAlertWithSender?> _findCachedAlert(String alertId) async {
    final cached = await _loadCachedAlerts();
    for (final item in cached) {
      if (item.alert.id == alertId) return item;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Active alerts for display in banner (global state)
  // ---------------------------------------------------------------------------
  static final ValueNotifier<List<EmergencyAlertWithSender>> activeAlertsNotifier =
      ValueNotifier([]);

  static final ValueNotifier<EmergencyAlertWithSender?> viewingAlertNotifier =
      ValueNotifier(null);

  // ---------------------------------------------------------------------------
  // Create SOS Alert
  // ---------------------------------------------------------------------------

  Future<EmergencyAlertModel?> createSosAlert({
    required double latitude,
    required double longitude,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[SOS] Offline');
      await _queueSosOffline(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
      );
      return null;
    }
    print('[AlertService] Online');

    print('[SOS] createSosAlert: userId=$userId, '
        'lat=$latitude, lng=$longitude');

    try {
      final familyService = FamilyService.defaultClient();
      final families = await familyService.fetchFamilies();

      if (families.isEmpty) {
        print('[SOS] createSosAlert: no families found');
        return null;
      }

      EmergencyAlertModel? firstAlert;

      for (final family in families) {
        final data = await _supabase
            .from('emergency_alerts')
            .insert({
              'family_id': family.id,
              'sender_id': userId,
              'latitude': latitude,
              'longitude': longitude,
              'status': 'active',
            })
            .select()
            .single();

        final alert = EmergencyAlertModel.fromJson(data);
        print('[SOS] createSosAlert: alert created for family '
            '${family.name} (${family.id}), alertId=${alert.id}');

        firstAlert ??= alert;
      }

      return firstAlert;
    } catch (e) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Cancel SOS Alert
  // ---------------------------------------------------------------------------

  Future<void> cancelSosAlert(String alertId) async {
    print('[SOS] cancelSosAlert: alertId=$alertId');
    if (!await _isOnline()) {
      print('[AlertService] Offline');
      return;
    }
    print('[AlertService] Online');
    try {
      await _supabase
          .from('emergency_alerts')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', alertId);
      print('[SOS] cancelSosAlert: cancelled');
    } catch (e) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
    }
  }

  // ---------------------------------------------------------------------------
  // Dismiss notification (permanent per-user, does NOT delete/cancel alert)
  // ---------------------------------------------------------------------------

  Future<void> dismissNotification(String alertId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _dismissedAlertIds.add(alertId);

    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
    } else {
      print('[AlertService] Online');
      try {
        await _supabase.from('notification_dismissals').insert({
          'user_id': userId,
          'alert_id': alertId,
        });
        print('[SOS] dismissNotification: alertId=$alertId');
      } catch (e) {
        print('[SOS] dismissNotification: ERROR=$e');
      }
    }

    final current = List<EmergencyAlertWithSender>.from(
      activeAlertsNotifier.value,
    );
    current.removeWhere((a) => a.alert.id == alertId);
    activeAlertsNotifier.value = current;

    final viewing = viewingAlertNotifier.value;
    if (viewing != null && viewing.alert.id == alertId) {
      viewingAlertNotifier.value = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch dismissed alert IDs for current user
  // ---------------------------------------------------------------------------

  Future<void> fetchDismissedAlertIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return;
    }
    print('[AlertService] Online');

    try {
      final rows = await _supabase
          .from('notification_dismissals')
          .select('alert_id')
          .eq('user_id', userId);

      _dismissedAlertIds.clear();
      for (final row in (rows as List)) {
        _dismissedAlertIds.add(row['alert_id'] as String);
      }
      print('[SOS] fetchDismissedAlertIds: ${_dismissedAlertIds.length} '
          'dismissed alerts loaded');
    } catch (e) {
      print('[SOS] fetchDismissedAlertIds: ERROR=$e');
    }
  }

  bool isDismissed(String alertId) => _dismissedAlertIds.contains(alertId);

  // ---------------------------------------------------------------------------
  // Update SOS Alert Location (for sender's live position)
  // ---------------------------------------------------------------------------

  Future<void> updateAlertLocation({
    required String alertId,
    required double latitude,
    required double longitude,
  }) async {
    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return;
    }
    print('[AlertService] Online');
    try {
      await _supabase
          .from('emergency_alerts')
          .update({
            'latitude': latitude,
            'longitude': longitude,
          })
          .eq('id', alertId);
      print('[SOS] updateAlertLocation: alertId=$alertId, '
          'lat=$latitude, lng=$longitude');
    } catch (e) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
    }
  }

  // ---------------------------------------------------------------------------
  // Start periodic location updates for active SOS
  // ---------------------------------------------------------------------------

  void startLocationUpdates(String alertId) {
    stopLocationUpdates();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateLocationFromUserLocations(alertId),
    );
    print('[SOS] startLocationUpdates: alertId=$alertId');
  }

  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    print('[SOS] stopLocationUpdates');
  }

  Future<void> _updateLocationFromUserLocations(String alertId) async {
    try {
      if (!await _isOnline()) {
        print('[AlertService] Offline');
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final locRow = await _supabase
          .from('user_locations')
          .select('latitude, longitude')
          .eq('user_id', userId)
          .maybeSingle();

      if (locRow == null) return;

      final lat = (locRow['latitude'] as num?)?.toDouble();
      final lng = (locRow['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      await updateAlertLocation(
        alertId: alertId,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      print('[SOS] _updateLocationFromUserLocations: ERROR=$e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch active alerts for user's families
  // ---------------------------------------------------------------------------

  Future<List<EmergencyAlertWithSender>> fetchActiveAlerts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return _loadCachedAlerts();
    }
    print('[AlertService] Online');

    print('[SOS] fetchActiveAlerts: userId=$userId');

    try {
      final rows = await _supabase
          .from('emergency_alerts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final alerts = <EmergencyAlertWithSender>[];

      for (final row in (rows as List)) {
        final alert = EmergencyAlertModel.fromJson(row);

        if (alert.senderId == userId) {
          print('[SOS] fetchActiveAlerts: filtered own alert '
              'alertId=${alert.id}');
          continue;
        }

        if (_dismissedAlertIds.contains(alert.id)) {
          print('[SOS] fetchActiveAlerts: filtered dismissed alert '
              'alertId=${alert.id}');
          continue;
        }

        final membership = await _supabase
            .from('family_members')
            .select('id')
            .eq('family_id', alert.familyId)
            .eq('user_id', userId)
            .maybeSingle();

        if (membership == null) continue;

        final profile = await _supabase
            .from('profiles')
            .select('id, name, photo_url')
            .eq('id', alert.senderId)
            .maybeSingle();

        alerts.add(EmergencyAlertWithSender(
          alert: alert,
          senderName: profile?['name'] as String? ?? 'Unknown',
          senderPhotoUrl: profile?['photo_url'] as String?,
        ));
      }

      print('[SOS] fetchActiveAlerts: ${alerts.length} active alerts');
      await AlertCacheService.instance.saveAlerts(
        alerts.map((a) => a.alert).toList(),
      );
      return alerts;
    } catch (e) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return _loadCachedAlerts();
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch alert history for user's families
  // ---------------------------------------------------------------------------

  Future<List<EmergencyAlertWithSender>> fetchAlertHistory({
    int limit = 50,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return _loadCachedAlerts();
    }
    print('[AlertService] Online');

    try {
      final rows = await _supabase
          .from('emergency_alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      final alerts = <EmergencyAlertWithSender>[];

      for (final row in (rows as List)) {
        final alert = EmergencyAlertModel.fromJson(row);

        final membership = await _supabase
            .from('family_members')
            .select('id')
            .eq('family_id', alert.familyId)
            .eq('user_id', userId)
            .maybeSingle();

        if (membership == null) continue;

        final profile = await _supabase
            .from('profiles')
            .select('id, name, photo_url')
            .eq('id', alert.senderId)
            .maybeSingle();

        alerts.add(EmergencyAlertWithSender(
          alert: alert,
          senderName: profile?['name'] as String? ?? 'Unknown',
          senderPhotoUrl: profile?['photo_url'] as String?,
        ));
      }

      await AlertCacheService.instance.saveAlerts(
        alerts.map((a) => a.alert).toList(),
      );
      return alerts;
    } catch (e) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return _loadCachedAlerts();
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch single alert with sender info
  // ---------------------------------------------------------------------------

  Future<EmergencyAlertWithSender?> fetchAlert(String alertId) async {
    if (!await _isOnline()) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return _findCachedAlert(alertId);
    }
    print('[AlertService] Online');

    try {
      final row = await _supabase
          .from('emergency_alerts')
          .select()
          .eq('id', alertId)
          .maybeSingle();

      if (row == null) return null;

      final alert = EmergencyAlertModel.fromJson(row);

      final profile = await _supabase
          .from('profiles')
          .select('id, name, photo_url')
          .eq('id', alert.senderId)
          .maybeSingle();

      return EmergencyAlertWithSender(
        alert: alert,
        senderName: profile?['name'] as String? ?? 'Unknown',
        senderPhotoUrl: profile?['photo_url'] as String?,
      );
    } catch (e) {
      print('[AlertService] Offline');
      print('[AlertService] Using cached alerts');
      return _findCachedAlert(alertId);
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime subscription for incoming alerts
  // ---------------------------------------------------------------------------

  void subscribeToAlerts(String userId) {
    unsubscribeFromAlerts();

    print('[SOS] subscribeToAlerts: userId=$userId');

    fetchDismissedAlertIds().then((_) {
      _alertsChannel = _supabase
          .channel('emergency-alerts-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'emergency_alerts',
            callback: (payload) => _handleAlertChange(payload, userId),
          )
          .subscribe();
    });
  }

  void unsubscribeFromAlerts() {
    if (_alertsChannel != null) {
      _supabase.removeChannel(_alertsChannel!);
      _alertsChannel = null;
      print('[SOS] unsubscribeFromAlerts');
    }
  }

  void _handleAlertChange(
    PostgresChangePayload payload,
    String userId,
  ) {
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    final alert = EmergencyAlertModel.fromJson(newRecord);
    final currentUserId = _supabase.auth.currentUser?.id;

    print('[SOS] _handleAlertChange: alertId=${alert.id}, '
        'senderId=${alert.senderId}, currentUserId=$currentUserId, '
        'status=${alert.status}');

    if (currentUserId == null) {
      print('[SOS] _handleAlertChange: no current user, skipping');
      return;
    }

    if (alert.senderId == currentUserId) {
      print('[SOS] Ignored Own SOS: senderId=${alert.senderId} '
          '== currentUserId=$currentUserId');
      return;
    }

    if (_processedAlertIds.contains(alert.id)) {
      print('[SOS] Duplicate Notification Ignored: alertId=${alert.id}');
      return;
    }

    if (_dismissedAlertIds.contains(alert.id)) {
      print('[SOS] Dismissed Alert Ignored: alertId=${alert.id}');
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _processedAlertIds.add(alert.id);
      _processAlertChange(alert, userId);
    });
  }

  Future<void> _processAlertChange(
    EmergencyAlertModel alert,
    String userId,
  ) async {
    try {
      print('[SOS] _processAlertChange: alertId=${alert.id}, '
          'status=${alert.status}');

      final alerts = await fetchActiveAlerts();
      activeAlertsNotifier.value = alerts;

      print('[SOS] SOS Notification Shown: ${alerts.length} active alerts');

      final viewing = viewingAlertNotifier.value;
      if (viewing != null && viewing.alert.id == alert.id) {
        final updated = await fetchAlert(alert.id);
        viewingAlertNotifier.value = updated;
      }
    } catch (e) {
      print('[SOS] _processAlertChange: ERROR=$e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    _debounceTimer?.cancel();
    _processedAlertIds.clear();
    _dismissedAlertIds.clear();
    unsubscribeFromAlerts();
    stopLocationUpdates();
  }
}

// ---------------------------------------------------------------------------
// Combined alert + sender info
// ---------------------------------------------------------------------------

class EmergencyAlertWithSender {
  final EmergencyAlertModel alert;
  final String senderName;
  final String? senderPhotoUrl;

  const EmergencyAlertWithSender({
    required this.alert,
    required this.senderName,
    this.senderPhotoUrl,
  });

  String get elapsedText {
    final d = alert.elapsed;
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
