import 'package:supabase_flutter/supabase_flutter.dart';

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
  final SupabaseClient _client;

  PrivacySettingsService(this._client);

  factory PrivacySettingsService.defaultClient() =>
      PrivacySettingsService(Supabase.instance.client);

  SupabaseClient get _supabase => _client;

  String get _userId => _supabase.auth.currentUser?.id ?? '';

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

    return PrivacySettingsModel.fromJson(row);
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

    return settings;
  }
}

class PrivacySettingsException implements Exception {
  final String message;
  const PrivacySettingsException(this.message);

  @override
  String toString() => message;
}
