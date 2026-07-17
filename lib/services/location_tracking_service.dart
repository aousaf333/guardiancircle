import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:guardiancircle/services/supabase_service.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastSupabaseUpdate;
  double _lastSupabaseLat = 0;
  double _lastSupabaseLng = 0;

  static const double _minDistanceMeters = 10;
  static const Duration _minTimeBetweenUpdates = Duration(seconds: 10);

  bool get isTracking => _positionSubscription != null;

  Stream<Position> get positionStream {
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

  void startTracking(void Function(Position position) onPositionUpdate) {
    stopTracking();

    _positionSubscription = positionStream.listen(
      (Position position) {
        _handlePositionUpdate(position, onPositionUpdate);
      },
      onError: (e) {},
    );
  }

  void _handlePositionUpdate(
    Position position,
    void Function(Position position) onPositionUpdate,
  ) {
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
      _upsertLocation(position);
    }

    onPositionUpdate(position);
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

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastSupabaseUpdate = null;
    _lastSupabaseLat = 0;
    _lastSupabaseLng = 0;
  }

  void dispose() {
    stopTracking();
  }
}
