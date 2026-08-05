import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:guardiancircle/models/family_model.dart';
import 'package:guardiancircle/services/family_cache_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('family_cache_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  setUp(() async {
    await LocalStorageService.instance.initialize();
    await LocalStorageService.instance.clearBox('cached_family');
  });

  tearDownAll(() async {
    await LocalStorageService.instance.closeBoxes();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('saveFamilies then loadCachedFamilies round-trips FamilyModel data',
      () async {
    final families = [
      FamilyModel(
        id: 'fam-1',
        name: 'Smith Family',
        inviteCode: 'ABCD1234',
        createdBy: 'user-1',
        createdAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
      ),
      FamilyModel(
        id: 'fam-2',
        name: 'Johnson Family',
        inviteCode: null,
        createdBy: 'user-2',
        createdAt: DateTime.parse('2026-02-01T10:00:00.000Z'),
      ),
    ];

    await FamilyCacheService.instance.saveFamilies(families);
    final cached = FamilyCacheService.instance.loadCachedFamilies();

    expect(cached.length, families.length);
    for (var i = 0; i < families.length; i++) {
      expect(cached[i].id, families[i].id);
      expect(cached[i].name, families[i].name);
      expect(cached[i].inviteCode, families[i].inviteCode);
      expect(cached[i].createdBy, families[i].createdBy);
      expect(cached[i].createdAt, families[i].createdAt);
    }
  });

  test('loadCachedFamilies returns an empty list when no cache exists',
      () async {
    final cached = FamilyCacheService.instance.loadCachedFamilies();

    expect(cached, isEmpty);
  });

  test('saveFamilies overwrites previously cached data', () async {
    await FamilyCacheService.instance.saveFamilies([
      FamilyModel(
        id: 'old',
        name: 'Old Family',
        inviteCode: null,
        createdBy: 'user-1',
        createdAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
      ),
    ]);

    final fresh = [
      FamilyModel(
        id: 'new',
        name: 'New Family',
        inviteCode: null,
        createdBy: 'user-1',
        createdAt: DateTime.parse('2026-03-01T10:00:00.000Z'),
      ),
    ];
    await FamilyCacheService.instance.saveFamilies(fresh);

    final cached = FamilyCacheService.instance.loadCachedFamilies();
    expect(cached.length, 1);
    expect(cached.single.id, 'new');
  });
}
