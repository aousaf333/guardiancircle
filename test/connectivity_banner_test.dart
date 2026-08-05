import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guardiancircle/services/connectivity_service.dart';
import 'package:guardiancircle/shared/widgets/connectivity_banner.dart';

class _FakeConnectivityPlatform extends ConnectivityPlatform {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> _current = [ConnectivityResult.wifi];

  void emit(List<ConnectivityResult> results) {
    _current = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;
}

Future<void> _pumpBanner(
  WidgetTester tester,
  ConnectivityService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConnectivityBanner(service: service),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late _FakeConnectivityPlatform fakePlatform;

  setUp(() {
    fakePlatform = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = fakePlatform;
  });

  testWidgets('shows red offline banner, then green Back Online banner',
      (tester) async {
    final service = ConnectivityService();
    await _pumpBanner(tester, service);

    expect(find.text('🔴 Offline Mode - Using cached data'), findsNothing);
    expect(find.text('🟢 Back Online'), findsNothing);

    fakePlatform.emit([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('🔴 Offline Mode - Using cached data'), findsOneWidget);
    expect(find.text('🟢 Back Online'), findsNothing);

    fakePlatform.emit([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('🔴 Offline Mode - Using cached data'), findsNothing);
    expect(find.text('🟢 Back Online'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('🟢 Back Online'), findsNothing);
    expect(find.text('🔴 Offline Mode - Using cached data'), findsNothing);

    service.dispose();
  });

  testWidgets('does not show a banner while online at startup', (tester) async {
    final service = ConnectivityService();
    await _pumpBanner(tester, service);

    expect(find.text('🟢 Back Online'), findsNothing);
    expect(find.text('🔴 Offline Mode - Using cached data'), findsNothing);

    service.dispose();
  });
}
