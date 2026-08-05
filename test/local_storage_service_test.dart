import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:guardiancircle/services/local_storage_service.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('initialize() initializes Hive and opens all boxes', () async {
    final service = LocalStorageService.instance;

    await service.initialize();

    expect(service.isInitialized, isTrue);
    for (final name in LocalStorageService.boxNames) {
      final box = service.box(name);
      expect(box, isNotNull, reason: '$name box should be open');
      expect(box!.isOpen, isTrue, reason: '$name box should be open');
    }

    await service.closeBoxes();
    expect(service.isInitialized, isFalse);
  });

  test('openBoxes is idempotent and clearBox removes entries', () async {
    final service = LocalStorageService.instance;

    await service.initialize();
    await service.openBoxes();

    final profiles = service.box('cached_profiles')!;
    await profiles.put('profile_1', {'name': 'Test'});
    expect(profiles.length, 1);

    await service.clearBox('cached_profiles');
    expect(profiles.isEmpty, isTrue);

    await service.closeBoxes();
  });
}
