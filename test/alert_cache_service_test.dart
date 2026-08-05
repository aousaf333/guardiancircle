import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:guardiancircle/models/emergency_alert_model.dart';
import 'package:guardiancircle/services/alert_cache_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('alert_cache_test_');
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
    await AlertCacheService.instance.clearCache();
  });

  tearDownAll(() async {
    await LocalStorageService.instance.closeBoxes();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  EmergencyAlertModel makeAlert({
    required String id,
    String familyId = 'fam-1',
    String senderId = 'user-1',
    double latitude = 1.23,
    double longitude = 4.56,
    String status = 'active',
  }) {
    return EmergencyAlertModel(
      id: id,
      familyId: familyId,
      senderId: senderId,
      latitude: latitude,
      longitude: longitude,
      status: status,
      createdAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
    );
  }

  test('saveAlerts then loadCachedAlerts round-trips alert data', () async {
    final alerts = [
      makeAlert(id: 'alert-1'),
      makeAlert(
        id: 'alert-2',
        familyId: 'fam-2',
        senderId: 'user-2',
        latitude: -1.23,
        longitude: -4.56,
        status: 'cancelled',
      ),
    ];

    await AlertCacheService.instance.saveAlerts(alerts);
    final cached = AlertCacheService.instance.loadCachedAlerts();

    expect(cached.length, alerts.length);
    for (var i = 0; i < alerts.length; i++) {
      expect(cached[i].id, alerts[i].id);
      expect(cached[i].familyId, alerts[i].familyId);
      expect(cached[i].senderId, alerts[i].senderId);
      expect(cached[i].latitude, alerts[i].latitude);
      expect(cached[i].longitude, alerts[i].longitude);
      expect(cached[i].status, alerts[i].status);
      expect(cached[i].createdAt, alerts[i].createdAt);
    }
  });

  test('loadCachedAlerts returns an empty list when no cache exists', () {
    final cached = AlertCacheService.instance.loadCachedAlerts();
    expect(cached, isEmpty);
  });

  test('saveAlerts overwrites previously cached data', () async {
    await AlertCacheService.instance.saveAlerts([makeAlert(id: 'old')]);
    await AlertCacheService.instance.saveAlerts([makeAlert(id: 'new')]);

    final cached = AlertCacheService.instance.loadCachedAlerts();
    expect(cached.length, 1);
    expect(cached.single.id, 'new');
  });
}
