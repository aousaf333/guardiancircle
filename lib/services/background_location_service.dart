import 'package:guardiancircle/services/location_tracking_service.dart';
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
class BackgroundLocationService {
  static bool _sharingEnabled = true;

  /// Whether location sharing is currently enabled.
  static bool get locationSharingEnabled => _sharingEnabled;

  /// Applies the persisted sharing preference and starts tracking when it
  /// should be running. Safe to call multiple times.
  static Future<void> initialize() async {
    await _loadSharingPreference();
    if (_sharingEnabled) {
      await start();
    }
  }

  /// Updates the sharing preference and starts/stops tracking accordingly.
  /// Called by the Settings screen whenever the user toggles location sharing.
  static Future<void> setLocationSharingEnabled(bool enabled) async {
    _sharingEnabled = enabled;
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  static Future<void> _loadSharingPreference() async {
    try {
      final settings =
          await PrivacySettingsService.defaultClient().fetchSettings();
      _sharingEnabled = settings.locationSharing;
    } catch (_) {
      // Keep the last known value when settings cannot be fetched.
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
