import 'package:hive/hive.dart';

import 'package:guardiancircle/models/family_model.dart';
import 'package:guardiancircle/services/local_storage_service.dart';

/// Offline cache for Family data backed by Hive.
///
/// All caching logic lives here and is isolated from the rest of the app. It
/// reads and writes the `cached_family` Hive box managed by
/// [LocalStorageService]. It never replaces Supabase; successfully fetched
/// data is simply mirrored so it can be served when there is no internet.
///
/// Usage:
/// ```dart
/// // Online: mirror fresh data into the cache.
/// await FamilyCacheService.instance.saveFamilies(families);
///
/// // Offline: serve the last known data (empty list if none cached).
/// final cached = FamilyCacheService.instance.loadCachedFamilies();
/// ```
class FamilyCacheService {
  FamilyCacheService._();

  static final FamilyCacheService instance = FamilyCacheService._();

  static const String _boxName = 'cached_family';
  static const String _familiesKey = 'families';

  Box<dynamic>? get _box => LocalStorageService.instance.box(_boxName);

  /// Persists the complete family list, overwriting any previous cache.
  ///
  /// Best-effort: Hive failures are logged and never propagated to callers.
  Future<void> saveFamilies(List<FamilyModel> families) async {
    try {
      final box = _box;
      if (box == null) {
        print('[FamilyCache] Hive box not open; skipping cache write.');
        return;
      }
      await box.put(_familiesKey, families.map((f) => f.toJson()).toList());
      print('[FamilyCache] Saving ${families.length} family records.');
    } catch (e) {
      print('[FamilyCache] Failed to save family data: $e');
    }
  }

  /// Loads the cached family list, or an empty list when no cache exists.
  ///
  /// Never throws, even when Hive or Supabase is unavailable.
  List<FamilyModel> loadCachedFamilies() {
    try {
      final box = _box;
      if (box == null) {
        print('[FamilyCache] No cached family data available.');
        return [];
      }

      print('[FamilyCache] Loading cached family data.');
      final raw = box.get(_familiesKey);
      if (raw is! List || raw.isEmpty) {
        print('[FamilyCache] No cached family data available.');
        return [];
      }

      final families = raw
          .whereType<Map>()
          .map((m) => FamilyModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      print('[FamilyCache] Loaded ${families.length} cached family records.');
      return families;
    } catch (e) {
      print('[FamilyCache] Failed to load family data: $e');
      return [];
    }
  }
}
