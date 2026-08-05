import 'package:hive_flutter/hive_flutter.dart';

/// Manages all Hive local storage operations for offline support.
///
/// Only prepares the Hive infrastructure for future offline caching. It does
/// not read or write any existing app data and does not replace Supabase.
///
/// Boxes:
/// - `cached_profiles`  - cached user profile data
/// - `cached_family`    - cached family member data
/// - `cached_locations` - cached location data
/// - `offline_queue`    - queued operations performed while offline
///
/// Usage:
/// ```dart
/// await LocalStorageService.instance.initialize();
/// // ...
/// await LocalStorageService.instance.closeBoxes();
/// ```
class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();

  /// The Hive box names managed by this service.
  static const List<String> boxNames = [
    'cached_profiles',
    'cached_family',
    'cached_locations',
    'offline_queue',
  ];

  final Map<String, Box> _boxes = {};
  bool _isInitialized = false;

  /// Whether Hive has been initialized and all boxes are open.
  bool get isInitialized => _isInitialized;

  /// Initializes Hive and opens all managed boxes.
  ///
  /// Safe to call more than once; a second call is a no-op.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    print('[Hive] Initialized');

    await openBoxes();

    _isInitialized = true;
    print('[Hive] Initialization completed');
  }

  /// Opens all managed Hive boxes.
  ///
  /// Safe to call more than once; boxes that are already open are kept.
  Future<void> openBoxes() async {
    for (final name in boxNames) {
      if (_boxes.containsKey(name)) continue;
      final box = await Hive.openBox<dynamic>(name);
      _boxes[name] = box;
      print('[Hive] Opened box: $name');
    }
  }

  /// Closes all open Hive boxes and clears the internal box registry.
  Future<void> closeBoxes() async {
    for (final name in boxNames) {
      final box = _boxes.remove(name);
      if (box != null) {
        await box.close();
        print('[Hive] Closed box: $name');
      }
    }
    _boxes.clear();
    _isInitialized = false;
  }

  /// Removes all entries from the given [boxName].
  ///
  /// Does nothing if the box is not currently open.
  Future<void> clearBox(String boxName) async {
    final box = _boxes[boxName];
    if (box == null) {
      print('[Hive] Clear skipped, box not open: $boxName');
      return;
    }
    await box.clear();
    print('[Hive] Cleared box: $boxName');
  }

  /// Returns the open [Box] for [boxName], or `null` if it is not open.
  Box<dynamic>? box(String boxName) => _boxes[boxName];
}
