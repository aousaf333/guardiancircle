import 'package:hive/hive.dart';

import 'package:guardiancircle/models/emergency_alert_model.dart';

/// Offline cache for Emergency Alert data backed by Hive.
///
/// All caching logic lives here and is isolated from the rest of the app. It
/// manages its own `cached_alerts` Hive box so it never replaces Supabase;
/// successfully fetched active alerts are simply mirrored so they can be
/// served when there is no internet.
///
/// Only the following data is cached per alert: alert id, family id, user
/// (sender) id, latitude, longitude, message, status and created_at. Sender
/// display info (name/photo) is intentionally NOT cached.
///
/// Usage:
/// ```dart
/// // Online: mirror fresh data into the cache.
/// await AlertCacheService.instance.saveAlerts(alerts);
///
/// // Offline: serve the last known data (empty list if none cached).
/// final cached = AlertCacheService.instance.loadCachedAlerts();
/// ```
class AlertCacheService {
  AlertCacheService._();

  static final AlertCacheService instance = AlertCacheService._();

  static const String _boxName = 'cached_alerts';
  static const String _alertsKey = 'alerts';

  Box<dynamic>? _box;
  bool _opened = false;

  Future<Box<dynamic>?> _getBox() async {
    if (_opened) return _box;
    try {
      _box = await Hive.openBox<dynamic>(_boxName);
      _opened = true;
    } catch (e) {
      print('[AlertCache] Failed to open Hive box: $e');
    }
    return _box;
  }

  /// Persists the active alerts, overwriting any previous cache.
  ///
  /// Best-effort: Hive failures are logged and never propagated to callers.
  Future<void> saveAlerts(List<EmergencyAlertModel> alerts) async {
    try {
      final box = await _getBox();
      if (box == null) {
        print('[AlertCache] Hive box not available; skipping cache write.');
        return;
      }
      print('[AlertCache] Saving alerts...');
      await box.put(_alertsKey, alerts.map(_toCacheMap).toList());
    } catch (e) {
      print('[AlertCache] Failed to save alerts: $e');
    }
  }

  /// Loads the cached alerts, or an empty list when no cache exists.
  ///
  /// Never throws, even when Hive or Supabase is unavailable.
  List<EmergencyAlertModel> loadCachedAlerts() {
    try {
      final box = _box;
      if (box == null || !box.isOpen) {
        print('[AlertCache] Loaded 0 cached alerts');
        return [];
      }

      final raw = box.get(_alertsKey);
      if (raw is! List || raw.isEmpty) {
        print('[AlertCache] Loaded 0 cached alerts');
        return [];
      }

      final alerts = raw
          .whereType<Map>()
          .map((m) => EmergencyAlertModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      print('[AlertCache] Loaded ${alerts.length} cached alerts');
      return alerts;
    } catch (e) {
      print('[AlertCache] Failed to load alerts: $e');
      return [];
    }
  }

  /// Removes all cached alerts. Used by tests and logout flows.
  Future<void> clearCache() async {
    try {
      final box = await _getBox();
      if (box == null) return;
      await box.clear();
      print('[AlertCache] Cleared cached alerts.');
    } catch (e) {
      print('[AlertCache] Failed to clear alerts: $e');
    }
  }

  Map<String, dynamic> _toCacheMap(EmergencyAlertModel alert) {
    return {
      'id': alert.id,
      'family_id': alert.familyId,
      'sender_id': alert.senderId,
      'latitude': alert.latitude,
      'longitude': alert.longitude,
      'message': null,
      'status': alert.status,
      'created_at': alert.createdAt.toUtc().toIso8601String(),
    };
  }
}
