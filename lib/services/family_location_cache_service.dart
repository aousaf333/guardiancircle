import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'package:guardiancircle/models/family_member_location.dart';
import 'package:guardiancircle/services/local_storage_service.dart';

/// Offline cache for family member locations backed by Hive.
///
/// Mirrors the last successfully loaded member list into the
/// `cached_locations` box so the map can keep showing markers when there is
/// no internet connection. Reads are best-effort and never throw.
class FamilyLocationCacheService {
  FamilyLocationCacheService._();

  static final FamilyLocationCacheService instance =
      FamilyLocationCacheService._();

  static const String _boxName = 'cached_locations';

  Box<dynamic>? get _box => LocalStorageService.instance.box(_boxName);

  String _key(String familyId) => 'family_member_locations_$familyId';

  /// Persists [members] for [familyId], overwriting any previous cache.
  Future<void> saveFamilyMemberLocations(
    String familyId,
    List<FamilyMemberLocation> members,
  ) async {
    try {
      final box = _box;
      if (box == null) {
        print('[FamilyLocationCache] Hive box not open; skipping cache write.');
        return;
      }
      await box.put(
        _key(familyId),
        members.map((m) => _toJson(m)).toList(),
      );
      print('[FamilyLocationCache] Saving ${members.length} member locations.');
    } catch (e) {
      print('[FamilyLocationCache] Failed to save member locations: $e');
    }
  }

  /// Loads the cached member locations for [familyId], or an empty list when
  /// no cache exists.
  List<FamilyMemberLocation> loadCachedFamilyMemberLocations(
    String familyId,
  ) {
    try {
      final box = _box;
      if (box == null) {
        print('[FamilyLocationCache] No cached member locations available.');
        return [];
      }

      final raw = box.get(_key(familyId));
      if (raw is! List || raw.isEmpty) {
        print('[FamilyLocationCache] No cached member locations available.');
        return [];
      }

      final members = raw
          .whereType<Map>()
          .map((m) => _fromJson(Map<String, dynamic>.from(m)))
          .toList();

      print('[FamilyLocationCache] Loaded ${members.length} cached member locations.');
      return members;
    } catch (e) {
      print('[FamilyLocationCache] Failed to load member locations: $e');
      return [];
    }
  }

  Map<String, dynamic> _toJson(FamilyMemberLocation m) {
    return {
      'userId': m.userId,
      'name': m.name,
      'role': m.role,
      'photoUrl': m.photoUrl,
      'color': m.color.toARGB32(),
      'latitude': m.latitude,
      'longitude': m.longitude,
      'lastUpdated': m.lastUpdated.toIso8601String(),
      'battery': m.battery,
      'isLocationHidden': m.isLocationHidden,
    };
  }

  FamilyMemberLocation _fromJson(Map<String, dynamic> json) {
    return FamilyMemberLocation(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      role: json['role'] as String? ?? 'Member',
      photoUrl: json['photoUrl'] as String?,
      color: Color(json['color'] as int? ?? 0xFF3B82F6),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] as String? ?? '') ??
              DateTime.now(),
      battery: (json['battery'] as num?)?.toDouble(),
      isLocationHidden: json['isLocationHidden'] as bool? ?? false,
    );
  }
}
