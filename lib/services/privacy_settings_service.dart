import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guardiancircle/services/connectivity_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';

class PrivacySettingsModel {
  final bool locationSharing;
  final bool invisibleMode;
  final bool notificationsEnabled;

  const PrivacySettingsModel({
    this.locationSharing = true,
    this.invisibleMode = false,
    this.notificationsEnabled = true,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      locationSharing: json['location_sharing'] as bool? ?? true,
      invisibleMode: json['invisible_mode'] as bool? ?? false,
      notificationsEnabled: json['notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'location_sharing': locationSharing,
        'invisible_mode': invisibleMode,
        'notifications': notificationsEnabled,
      };

  PrivacySettingsModel copyWith({
    bool? locationSharing,
    bool? invisibleMode,
    bool? notificationsEnabled,
  }) {
    return PrivacySettingsModel(
      locationSharing: locationSharing ?? this.locationSharing,
      invisibleMode: invisibleMode ?? this.invisibleMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

class PrivacySettingsService {
  // ---------------------------------------------------------------------------
  // Connectivity + offline auto-sync
  // ---------------------------------------------------------------------------

  static final ConnectivityService _sharedConnectivity = ConnectivityService();
  static bool _connectivityInitialized = false;
  static StreamSubscription<bool>? _offlineSyncSubscription;
  static bool _offlineSyncWasOnline = false;
  static bool _syncInProgress = false;

  /// Starts listening for connectivity changes and automatically pushes any
  /// locally saved settings changes to Supabase once internet is restored.
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
    print('[Settings] Listening for connectivity changes');
  }

  static void _onConnectivityChanged(bool online) {
    if (online && !_offlineSyncWasOnline) {
      PrivacySettingsService.defaultClient().syncPendingChanges();
    }
    _offlineSyncWasOnline = online;
  }

  final SupabaseClient _client;

  PrivacySettingsService(this._client);

  factory PrivacySettingsService.defaultClient() =>
      PrivacySettingsService(Supabase.instance.client);

  SupabaseClient get _supabase => _client;

  String get _userId => _supabase.auth.currentUser?.id ?? '';

  /// Hive box that mirrors the settings locally so toggles survive restarts
  /// even when the device is offline.
  static const String _localBoxName = 'cached_privacy_settings';

  Box<dynamic>? get _localBox =>
      LocalStorageService.instance.box(_localBoxName);

  /// Reads the settings previously persisted on this device, or `null` when
  /// nothing has been saved yet. Best-effort and never throws.
  Future<PrivacySettingsModel?> fetchSettingsLocal() async {
    final userId = _userId;
    if (userId.isEmpty) return null;

    final box = _localBox;
    if (box == null) return null;

    final raw = box.get(userId);
    if (raw is! Map) return null;

    return PrivacySettingsModel.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Persists [settings] to the local Hive cache. When [needsSync] is true the
  /// entry is flagged so it can be pushed to Supabase once online (e.g. after
  /// an offline save).
  Future<void> saveSettingsLocal(
    PrivacySettingsModel settings, {
    bool needsSync = false,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) return;

    final box = _localBox;
    if (box == null) return;

    await box.put(userId, {
      ...settings.toJson(),
      if (needsSync) 'needs_sync': true,
    });
  }

  /// Pushes a locally flagged (unsynced) settings entry to Supabase and clears
  /// the flag on success. Returns the pushed settings, or `null` when there is
  /// nothing pending or the user is not authenticated.
  Future<PrivacySettingsModel?> syncPendingChanges() async {
    if (_syncInProgress) return null;
    final userId = _userId;
    if (userId.isEmpty) return null;

    final box = _localBox;
    if (box == null) return null;

    final raw = box.get(userId);
    if (raw is! Map) return null;
    if (raw['needs_sync'] != true) return null;

    _syncInProgress = true;
    try {
      final settings = PrivacySettingsModel.fromJson(
        Map<String, dynamic>.from(raw),
      );
      await saveSettings(settings);
      return settings;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<PrivacySettingsModel> fetchSettings() async {
    final userId = _userId;
    if (userId.isEmpty) return const PrivacySettingsModel();

    final row = await _supabase
        .from('privacy_settings')
        .select('location_sharing, invisible_mode, notifications')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      return const PrivacySettingsModel();
    }

    final settings = PrivacySettingsModel.fromJson(row);

    final box = _localBox;
    final pending = box?.get(_userId);
    final hasPending = pending is Map && pending['needs_sync'] == true;
    if (!hasPending) {
      await saveSettingsLocal(settings, needsSync: false);
    }
    return settings;
  }

  Future<PrivacySettingsModel> saveSettings(PrivacySettingsModel settings) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const PrivacySettingsException('User not authenticated.');
    }

    await _supabase.from('privacy_settings').upsert(
      {
        'user_id': userId,
        ...settings.toJson(),
      },
      onConflict: 'user_id',
    );

    await saveSettingsLocal(settings, needsSync: false);
    print('[Privacy] Synced (invisible_mode=${settings.invisibleMode})');
    print(
        '[LocationSharing] Synced (location_sharing=${settings.locationSharing})');
    print(
        '[Notifications] Synced (notifications=${settings.notificationsEnabled})');

    return settings;
  }
}

class PrivacySettingsException implements Exception {
  final String message;
  const PrivacySettingsException(this.message);

  @override
  String toString() => message;
}
