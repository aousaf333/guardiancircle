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
    tempDir = await Directory.systemTemp.createTemp('offline_location_test_');
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
    await LocalStorageService.instance.clearBox('offline_location_queue');
  });

  tearDownAll(() async {
    await LocalStorageService.instance.closeBoxes();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> makeLocationQueueEntry({
    String userId = 'user-1',
    double latitude = 1.23,
    double longitude = 4.56,
    double accuracy = 7.0,
    double speed = 0.5,
    double heading = 90.0,
    String? timestamp,
  }) {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  test('offline_location_queue box round-trips a queued location entry',
      () async {
    final box = LocalStorageService.instance.box('offline_location_queue');
    expect(box, isNotNull);

    await box!.add(makeLocationQueueEntry());

    final queued = box.values.toList();
    expect(queued.length, 1);

    final stored = queued.single as Map;
    expect(stored['userId'], 'user-1');
    expect(stored['latitude'], 1.23);
    expect(stored['longitude'], 4.56);
    expect(stored['accuracy'], 7.0);
    expect(stored['speed'], 0.5);
    expect(stored['heading'], 90.0);
    expect(stored['timestamp'], isA<String>());
  });

  test('offline_location_queue preserves queued entries in order', () async {
    final box = LocalStorageService.instance.box('offline_location_queue')!;

    await box.add(makeLocationQueueEntry(userId: 'user-a'));
    await box.add(makeLocationQueueEntry(userId: 'user-b'));

    final queued = box.values.toList();
    expect(queued.length, 2);
    expect((queued[0] as Map)['userId'], 'user-a');
    expect((queued[1] as Map)['userId'], 'user-b');
  });

  test('clearBox empties the offline location queue', () async {
    final box = LocalStorageService.instance.box('offline_location_queue')!;
    await box.add(makeLocationQueueEntry());

    await LocalStorageService.instance.clearBox('offline_location_queue');

    expect(box.values, isEmpty);
  });
}
