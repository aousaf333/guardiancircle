import 'dart:async';

import 'package:flutter/material.dart';

import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/services/connectivity_service.dart';

/// A self-contained banner that reflects the device connectivity state via
/// the [ConnectivityService].
///
/// - While offline, a persistent red banner is shown at the top:
///   "🔴 Offline Mode - Using cached data"
/// - When connectivity is restored, a green banner is shown for
///   [onlineBannerDuration]:
///   "🟢 Back Online"
///
/// The widget renders nothing itself; it manages an [OverlayEntry] on the
/// nearest [Overlay], so the banner floats above all screens. It respects the
/// device SafeArea and never covers the status bar.
class ConnectivityBanner extends StatefulWidget {
  /// The connectivity service to listen to.
  ///
  /// When omitted, the widget creates and owns a [ConnectivityService].
  final ConnectivityService? service;

  /// How long the "Back Online" banner stays visible before hiding.
  final Duration onlineBannerDuration;

  const ConnectivityBanner({
    super.key,
    this.service,
    this.onlineBannerDuration = const Duration(seconds: 2),
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

enum _BannerType { offline, online }

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  static const double _bannerHeight = 44;

  late final ConnectivityService _service;
  late final bool _ownsService;
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  StreamSubscription<bool>? _subscription;
  OverlayEntry? _overlayEntry;
  Timer? _onlineBannerTimer;
  _BannerType? _currentType;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? ConnectivityService();
    _ownsService = widget.service == null;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_onAnimationStatus);
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _service.initialize();
    _subscription = _service.isOnline.listen(_onConnectivityChanged);
  }

  @override
  Widget build(BuildContext context) {
    // The banner is rendered via an [OverlayEntry]; this widget itself
    // renders nothing so it never affects the surrounding layout.
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _onlineBannerTimer?.cancel();
    _subscription?.cancel();
    _removeOverlay();
    _controller.dispose();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;

    if (online) {
      print('[Connectivity] Online');
      // Only show the "Back Online" banner when returning from offline.
      if (_currentType == _BannerType.offline) {
        _showBanner(_BannerType.online);
      }
    } else {
      print('[Connectivity] Offline');
      _showBanner(_BannerType.offline);
    }
  }

  void _showBanner(_BannerType type) {
    _onlineBannerTimer?.cancel();
    _onlineBannerTimer = null;
    _currentType = type;

    if (_overlayEntry == null) {
      _insertOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }

    if (!_controller.isCompleted) {
      _controller.forward();
    }

    if (type == _BannerType.online) {
      _onlineBannerTimer = Timer(widget.onlineBannerDuration, () {
        if (!mounted) return;
        _currentType = null;
        _controller.reverse();
      });
    }
  }

  void _insertOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.paddingOf(overlayContext).top,
          left: 0,
          right: 0,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return _ConnectivityBannerView(
                  type: _currentType == _BannerType.offline
                      ? _BannerType.offline
                      : _BannerType.online,
                  animation: _slide,
                  height: _bannerHeight,
                );
              },
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _removeOverlay();
    }
  }
}

class _ConnectivityBannerView extends StatelessWidget {
  final _BannerType type;
  final Animation<Offset> animation;
  final double height;

  const _ConnectivityBannerView({
    required this.type,
    required this.animation,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline = type == _BannerType.offline;

    return SafeArea(
      top: false,
      bottom: false,
      child: SlideTransition(
        position: animation,
        child: Material(
          color: isOffline ? AppTheme.danger : AppTheme.success,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(
              child: Text(
                isOffline
                    ? '🔴 Offline Mode - Using cached data'
                    : '🟢 Back Online',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
