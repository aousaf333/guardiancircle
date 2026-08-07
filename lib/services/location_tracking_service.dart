import 'dart:async';
import 'dart:math';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardiancircle/models/self_location_info.dart';
import 'package:guardiancircle/services/local_storage_service.dart';
import 'package:guardiancircle/services/offline_location_sync_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';

class LocationTrackingService {
  LocationTrackingService._();

  /// Single shared instance used by the map and the background tracking
  /// service so that at most one position stream is active at a time.
  static final LocationTrackingService instance = LocationTrackingService._();

  /// When false (privacy mode), live positions are still tracked locally so
  /// SOS and the map keep working, but nothing is uploaded to or queued for
  /// Supabase. Toggled by [BackgroundLocationService].
  static bool uploadLocationsToServer = true;

  /// Whether location sharing is currently enabled. When false no live
  /// positions are uploaded or queued, even while the map keeps its own GPS
  /// stream open. Toggled by [BackgroundLocationService].
  static bool locationSharingEnabled = true;

  StreamSubscription<Position>? _positionSubscription;
  void Function(Position position)? _onPositionUpdate;
  DateTime? _lastSupabaseUpdate;
  double _lastSupabaseLat = 0;
  double _lastSupabaseLng = 0;
  DateTime? _lastHistoryUpdate;
  double _lastHistoryLat = 0;
  double _lastHistoryLng = 0;

  static const double _minDistanceMeters = 10;
  static const Duration _minTimeBetweenUpdates = Duration(seconds: 10);
  static const double _historyMinDistanceMeters = 25;
  static const Duration _historyMinTimeBetweenUpdates = Duration(minutes: 2);

  /// Hive box + key used to persist the last real self location so it can be
  /// shown while offline or when a fresh fix cannot be obtained.
  static const String _selfLocationBoxName = 'cached_locations';
  static const String _selfLocationKey = 'self_current_location';
  static const double _cacheMinDistanceMeters = 25;
  static const Duration _cacheMinTimeBetweenUpdates = Duration(minutes: 2);

  /// The most recent position received from the GPS stream, if any.
  Position? _lastPosition;
  double _lastCachedSelfLat = 0;
  double _lastCachedSelfLng = 0;
  DateTime? _lastCachedSelfTime;

  bool get isTracking => _positionSubscription != null;

  /// The most recent live position received from the GPS stream, if any.
  Position? get lastKnownPosition => _lastPosition;

  Stream<Position> get positionStream {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 5,
          timeLimit: null,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'GuardianCircle',
            notificationText: 'Live location sharing is active',
            notificationChannelName: 'Location Sharing',
            enableWakeLock: true,
            setOngoing: true,
            notificationIcon: AndroidResource(
              name: 'ic_launcher',
              defType: 'mipmap',
            ),
            color: Color(0xFF2563EB),
          ),
        ),
      );
    }

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5,
        timeLimit: null,
      ),
    );
  }

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void startTracking([void Function(Position position)? onPositionUpdate]) {
    if (onPositionUpdate != null) {
      _onPositionUpdate = onPositionUpdate;
    }
    if (_positionSubscription != null) return;

    _positionSubscription = positionStream.listen(
      (Position position) {
        _handlePositionUpdate(position, _onPositionUpdate);
      },
      onError: (e) {},
    );
  }

  void _handlePositionUpdate(
    Position position,
    void Function(Position position)? onPositionUpdate,
  ) {
    print('[BackgroundTracking] Location received');
    _lastPosition = position;
    _maybeCacheSelfPosition(position);
    if (!locationSharingEnabled || !uploadLocationsToServer) {
      onPositionUpdate?.call(position);
      return;
    }

    final now = DateTime.now();
    final distance = _calculateDistance(
      _lastSupabaseLat,
      _lastSupabaseLng,
      position.latitude,
      position.longitude,
    );

    final timeSinceLastUpdate = _lastSupabaseUpdate != null
        ? now.difference(_lastSupabaseUpdate!)
        : _minTimeBetweenUpdates;

    final shouldUpdateSupabase =
        distance >= _minDistanceMeters || timeSinceLastUpdate >= _minTimeBetweenUpdates;

    if (shouldUpdateSupabase) {
      _lastSupabaseLat = position.latitude;
      _lastSupabaseLng = position.longitude;
      _lastSupabaseUpdate = now;
      if (OfflineLocationSyncService.isCurrentlyOffline) {
        OfflineLocationSyncService.enqueueLocation(position);
        print('[BackgroundTracking] Location queued');
      } else {
        _upsertLocation(position);
      }
    }

    onPositionUpdate?.call(position);
  }

  Future<void> _upsertLocation(Position position) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;

      await SupabaseService.client.from('user_locations').upsert(
        {
          'user_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id',
      );

      print('[BackgroundTracking] Location uploaded');
      await _saveLocationHistory(userId, position);
    } catch (_) {}
  }

  Future<void> _saveLocationHistory(String userId, Position position) async {
    try {
      final now = DateTime.now();
      final distance = _calculateDistance(
        _lastHistoryLat,
        _lastHistoryLng,
        position.latitude,
        position.longitude,
      );
      final timeSinceLastHistory = _lastHistoryUpdate != null
          ? now.difference(_lastHistoryUpdate!)
          : _historyMinTimeBetweenUpdates;
      final shouldSaveHistory =
          distance >= _historyMinDistanceMeters || timeSinceLastHistory >= _historyMinTimeBetweenUpdates;
      if (!shouldSaveHistory) return;

      _lastHistoryLat = position.latitude;
      _lastHistoryLng = position.longitude;
      _lastHistoryUpdate = now;

      print('[LocationTracking] History Saved: userId=$userId, '
          'lat=${position.latitude}, lng=${position.longitude}');
      await SupabaseService.client.from('location_history').insert({
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  // ---------------------------------------------------------------------------
  // Self location (home screen / location details)
  // ---------------------------------------------------------------------------

  /// Fetches the current GPS position, returning `null` when unavailable.
  ///
  /// A successful fix is mirrored into the local self-location cache so it can
  /// be shown as the last known real location while offline.
  Future<Position?> getCurrentPositionOrNull() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _cacheSelfPosition(position);
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Resolves [latitude]/[longitude] to a [Placemark] using the platform
  /// geocoder, or `null` when no placemark can be determined.
  Future<Placemark?> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      return placemarks.isEmpty ? null : placemarks.first;
    } catch (_) {
      return null;
    }
  }

  /// Loads the last real self location persisted to Hive, or `null` when no
  /// cached fix exists.
  Future<Position?> loadCachedSelfLocation() async {
    try {
      final box = LocalStorageService.instance.box(_selfLocationBoxName);
      if (box == null) return null;
      final raw = box.get(_selfLocationKey);
      if (raw is! Map) return null;
      final latitude = raw['latitude'];
      final longitude = raw['longitude'];
      if (latitude == null || longitude == null) return null;
      return Position(
        latitude: (latitude as num).toDouble(),
        longitude: (longitude as num).toDouble(),
        timestamp: DateTime.tryParse(raw['timestamp'] as String? ?? '') ??
            DateTime.now(),
        accuracy: (raw['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: (raw['altitude'] as num?)?.toDouble() ?? 0,
        altitudeAccuracy: 0,
        heading: (raw['heading'] as num?)?.toDouble() ?? 0,
        headingAccuracy: 0,
        speed: (raw['speed'] as num?)?.toDouble() ?? 0,
        speedAccuracy: 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the current real location with an optional reverse-geocoded
  /// placemark, or `null` when the location is unavailable (permission denied,
  /// GPS failure with no cached fix).
  ///
  /// Falls back to the last cached self location when a fresh GPS fix cannot
  /// be obtained.
  Future<SelfLocationInfo?> loadSelfLocationInfo() async {
    if (!await checkAndRequestPermission()) return null;

    Position? position = await getCurrentPositionOrNull();
    final fromCache = position == null;
    position ??= await loadCachedSelfLocation();
    if (position == null) return null;

    final placemark = await reverseGeocode(
      position.latitude,
      position.longitude,
    );
    return SelfLocationInfo(
      position: position,
      placemark: placemark,
      fromCache: fromCache,
    );
  }

  void _maybeCacheSelfPosition(Position position) {
    final now = DateTime.now();
    final distance = _calculateDistance(
      _lastCachedSelfLat,
      _lastCachedSelfLng,
      position.latitude,
      position.longitude,
    );
    final timeSince = _lastCachedSelfTime != null
        ? now.difference(_lastCachedSelfTime!)
        : _cacheMinTimeBetweenUpdates;
    if (distance < _cacheMinDistanceMeters &&
        timeSince < _cacheMinTimeBetweenUpdates) {
      return;
    }
    _lastCachedSelfLat = position.latitude;
    _lastCachedSelfLng = position.longitude;
    _lastCachedSelfTime = now;
    _cacheSelfPosition(position);
  }

  Future<void> _cacheSelfPosition(Position position) async {
    try {
      final box = LocalStorageService.instance.box(_selfLocationBoxName);
      if (box == null) return;
      await box.put(_selfLocationKey, {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': position.timestamp.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _onPositionUpdate = null;
    _lastSupabaseUpdate = null;
    _lastSupabaseLat = 0;
    _lastSupabaseLng = 0;
    _lastHistoryUpdate = null;
    _lastHistoryLat = 0;
    _lastHistoryLng = 0;
  }

  void dispose() {
    stopTracking();
  }
}
