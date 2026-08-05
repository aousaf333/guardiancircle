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
    tempDir = await Directory.systemTemp.createTemp('offline_queue_test_');
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
    await LocalStorageService.instance.clearBox('offline_queue');
  });

  tearDownAll(() async {
    await LocalStorageService.instance.closeBoxes();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> makeSosQueueEntry({
    String userId = 'user-1',
    double latitude = 1.23,
    double longitude = 4.56,
    String? message,
    String type = 'sos',
  }) {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'type': type,
    };
  }

  test('offline_queue box round-trips a queued SOS entry', () async {
    final box = LocalStorageService.instance.box('offline_queue');
    expect(box, isNotNull);

    final entry = makeSosQueueEntry();
    await box!.add(entry);

    final queued = box.values.toList();
    expect(queued.length, 1);

    final stored = queued.single as Map;
    expect(stored['userId'], 'user-1');
    expect(stored['latitude'], 1.23);
    expect(stored['longitude'], 4.56);
    expect(stored['type'], 'sos');
    expect(stored['timestamp'], isA<String>());
    expect(stored.containsKey('message'), isTrue);
  });

  test('offline_queue preserves multiple queued entries in order', () async {
    final box = LocalStorageService.instance.box('offline_queue')!;

    await box.add(makeSosQueueEntry(userId: 'user-a'));
    await box.add(makeSosQueueEntry(userId: 'user-b'));

    final queued = box.values.toList();
    expect(queued.length, 2);
    expect((queued[0] as Map)['userId'], 'user-a');
    expect((queued[1] as Map)['userId'], 'user-b');
  });

  test('clearBox empties the offline queue', () async {
    final box = LocalStorageService.instance.box('offline_queue')!;
    await box.add(makeSosQueueEntry());

    await LocalStorageService.instance.clearBox('offline_queue');

    expect(box.values, isEmpty);
  });
}
