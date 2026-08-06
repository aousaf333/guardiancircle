import 'package:guardiancircle/services/location_tracking_service.dart';
import 'package:guardiancircle/services/notification_service.dart';
import 'package:guardiancircle/services/privacy_settings_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';

/// App-scoped controller that keeps live location tracking running (on Android
/// as a foreground service with a persistent notification) while the user is
/// signed in and has location sharing enabled.
///
/// It drives the single [LocationTrackingService.instance] stream, which owns
/// the actual GPS subscription, uploads and offline queueing. Screens may call
/// [resumeTracking] whenever tracking could have been lost to hand control
/// back to the background service.
///
/// Privacy mode ([setPrivacyEnabled]) keeps tracking and GPS available for SOS
/// but stops the stream from uploading or queuing any location, and removes the
/// user's live row from `user_locations` so family members see "Location
/// Hidden" instead of coordinates.
class BackgroundLocationService {
  static bool _sharingEnabled = true;
  static bool _privacyEnabled = false;

  /// Whether location sharing is currently enabled.
  static bool get locationSharingEnabled => _sharingEnabled;

  /// Whether privacy mode is currently enabled (live location hidden).
  static bool get privacyEnabled => _privacyEnabled;

  /// Applies the persisted settings (sharing, privacy, notifications) and
  /// starts tracking when it should be running. Safe to call multiple times.
  static Future<void> initialize() async {
    await _loadSettings();
    if (_sharingEnabled) {
      await start();
    }
  }

  /// Updates the sharing preference and starts/stops tracking accordingly.
  /// Called by the Settings screen whenever the user toggles location sharing.
  static Future<void> setLocationSharingEnabled(bool enabled) async {
    _sharingEnabled = enabled;
    LocationTrackingService.locationSharingEnabled = enabled;
    if (enabled) {
      print('[LocationSharing] Enabled');
      await start();
    } else {
      print('[LocationSharing] Disabled');
      await stop();
    }
  }

  /// Enables or disables privacy mode. While enabled, live positions are no
  /// longer uploaded to or queued for Supabase and the existing `user_locations`
  /// row is removed so other family members see the member as location hidden.
  static Future<void> setPrivacyEnabled(bool enabled) async {
    _privacyEnabled = enabled;
    LocationTrackingService.uploadLocationsToServer = !enabled;
    if (enabled) {
      print('[Privacy] Enabled');
      await _removeUserLocation();
    } else {
      print('[Privacy] Disabled');
    }
  }

  static Future<void> _removeUserLocation() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;
      await SupabaseService.client
          .from('user_locations')
          .delete()
          .eq('user_id', userId);
      print('[Privacy] Location removed from server');
    } catch (e) {
      print('[Privacy] Failed to remove location: $e');
    }
  }

  static Future<void> _loadSettings() async {
    final service = PrivacySettingsService.defaultClient();

    // 1. Restore the last known settings from the local cache immediately so
    //    toggles survive restarts even while offline.
    PrivacySettingsModel? cached;
    try {
      cached = await service.fetchSettingsLocal();
    } catch (_) {
      cached = null;
    }
    if (cached != null) {
      _sharingEnabled = cached.locationSharing;
      _privacyEnabled = cached.invisibleMode;
      LocationTrackingService.locationSharingEnabled = cached.locationSharing;
      LocationTrackingService.uploadLocationsToServer =
          !cached.invisibleMode;
      NotificationService.setNotificationsEnabled(cached.notificationsEnabled);
    }

    // 2. Push any change made while offline, then refresh from Supabase.
    try {
      await service.syncPendingChanges();
      final remote = await service.fetchSettings();
      _sharingEnabled = remote.locationSharing;
      _privacyEnabled = remote.invisibleMode;
      LocationTrackingService.locationSharingEnabled = remote.locationSharing;
      LocationTrackingService.uploadLocationsToServer =
          !remote.invisibleMode;
      NotificationService.setNotificationsEnabled(remote.notificationsEnabled);
    } catch (_) {
      // Keep the locally cached values when the network is unavailable.
    }
  }

  /// Starts the location stream (foreground service on Android) if it is not
  /// already running.
  static Future<void> start() => _ensureRunning('Service started');

  /// Restarts tracking after the app is reopened or resumed, or after a screen
  /// stopped the shared stream (e.g. the map closing).
  static Future<void> resumeTracking() => _ensureRunning('Tracking resumed');

  static Future<void> _ensureRunning(String logPrefix) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (!_sharingEnabled) return;

    final tracking = LocationTrackingService.instance;
    if (tracking.isTracking) return;
    if (!await tracking.isLocationServiceEnabled() || !await tracking.hasPermission()) {
      print('[BackgroundTracking] Skipping start: location services or permission unavailable');
      return;
    }

    tracking.startTracking();
    print('[BackgroundTracking] $logPrefix');
  }

  /// Stops the location stream and removes the foreground notification.
  static Future<void> stop() async {
    if (!LocationTrackingService.instance.isTracking) return;
    LocationTrackingService.instance.stopTracking();
    print('[BackgroundTracking] Service stopped');
  }
}
