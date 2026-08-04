import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors internet connectivity using the [connectivity_plus] plugin.
///
/// Exposes a [Stream] of `bool` (true = online) via [isOnline] and detects
/// WiFi, Mobile and No-Internet states.
///
/// Usage:
/// ```dart
/// final connectivityService = ConnectivityService();
/// await connectivityService.initialize();
/// connectivityService.isOnline.listen((bool online) {
///   print('Online: $online');
/// });
/// // ...
/// connectivityService.dispose();
/// ```
class ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<bool> _isOnlineController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// The connectivity state as a broadcast [Stream].
  ///
  /// Emits `true` when the device is connected to a network that provides
  /// internet access (WiFi, Mobile, Ethernet, VPN, etc.) and `false` when
  /// there is no connectivity.
  Stream<bool> get isOnline => _isOnlineController.stream;

  /// Current connectivity state. `true` when online.
  ///
  /// Defaults to `false` until [initialize] completes.
  bool isCurrentlyOnline = false;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Checks the current connectivity state and starts listening for changes.
  ///
  /// Safe to call more than once; any previous listener is stopped first.
  Future<void> initialize() async {
    _stopListening();

    try {
      final results = await _connectivity.checkConnectivity();
      _handleResults(results);
    } catch (e) {
      print('[ConnectivityService] Failed to check initial connectivity: $e');
      _isOnlineController.add(false);
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleResults,
      onError: (Object e) {
        print('[ConnectivityService] Connectivity stream error: $e');
        isCurrentlyOnline = false;
        _isOnlineController.add(false);
      },
    );
  }

  void _handleResults(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      print('[ConnectivityService] No connectivity information available.');
      isCurrentlyOnline = false;
      _isOnlineController.add(false);
      return;
    }

    final hasInternet =
        results.any((result) => result != ConnectivityResult.none);

    if (hasInternet) {
      print('[ConnectivityService] Online via: '
          '${results.where((r) => r != ConnectivityResult.none).join(', ')}');
    } else {
      print('[ConnectivityService] No Internet connection detected.');
    }

    isCurrentlyOnline = hasInternet;
    _isOnlineController.add(hasInternet);
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Stops listening for connectivity changes.
  ///
  /// The [isOnline] stream remains usable; call [initialize] again to resume.
  void dispose() {
    _stopListening();
    _isOnlineController.close();
  }
}
