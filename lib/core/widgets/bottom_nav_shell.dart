import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/services/emergency_alert_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';

class BottomNavShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({required this.navigationShell, super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  late final EmergencyAlertService _alertService;
  OverlayEntry? _bannerOverlay;

  @override
  void initState() {
    super.initState();
    print('[BottomNavShell] initState');
    _alertService = EmergencyAlertService.defaultClient();
    _initAlertSubscription();
    EmergencyAlertService.activeAlertsNotifier.addListener(_onAlertsChanged);
  }

  @override
  void dispose() {
    print('[BottomNavShell] dispose');
    EmergencyAlertService.activeAlertsNotifier
        .removeListener(_onAlertsChanged);
    _removeOverlay();
    _alertService.dispose();
    super.dispose();
  }

  void _initAlertSubscription() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      print('[BottomNavShell] _initAlertSubscription: no userId, skipping');
      return;
    }
    print('[BottomNavShell] _initAlertSubscription: subscribing for $userId');
    _alertService.subscribeToAlerts(userId);
    _alertService.fetchActiveAlerts().then((alerts) {
      if (mounted) {
        print('[BottomNavShell] _initAlertSubscription: '
            'loaded ${alerts.length} active alerts');
        EmergencyAlertService.activeAlertsNotifier.value = alerts;
      }
    });
  }

  void _onAlertsChanged() {
    final alerts = EmergencyAlertService.activeAlertsNotifier.value;
    if (alerts.isNotEmpty && _bannerOverlay == null) {
      _insertOverlay();
    } else if (alerts.isEmpty && _bannerOverlay != null) {
      _removeOverlay();
    }
  }

  void _insertOverlay() {
    _bannerOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top,
          left: 0,
          right: 0,
          child: _EmergencyBanner(),
        );
      },
    );
    Overlay.of(context).insert(_bannerOverlay!);
  }

  void _removeOverlay() {
    _bannerOverlay?.remove();
    _bannerOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: _PremiumBottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
 @override
Widget build(BuildContext context) {
  return ValueListenableBuilder<List<EmergencyAlertWithSender>>(
    valueListenable: EmergencyAlertService.activeAlertsNotifier,
    builder: (_, alerts, _) {
      if (alerts.isEmpty) return const SizedBox.shrink();

      print('[SOS Banner] SOS Notification Shown: ${alerts.length} alerts');

      return Material(
        color: Colors.transparent,
        elevation: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: alerts
              .map((a) => _BannerTile(
                    alertData: a,
                    key: ValueKey('banner_${a.alert.id}'),
                  ))
              .toList(),
        ),
      );
    },
  );
}
}
class _BannerTile extends StatefulWidget {
  final EmergencyAlertWithSender alertData;
  const _BannerTile({required this.alertData, super.key});
  @override
  State<_BannerTile> createState() => _BannerTileState();
}

class _BannerTileState extends State<_BannerTile>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dismissController;
  late final Animation<double> _dismissFade;
  late final Animation<Offset> _dismissSlide;
  bool _isNavigating = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dismissFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _dismissController,
        curve: Curves.easeOut,
      ),
    );
    _dismissSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.5, 0),
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    _pulseController.stop();

    final service = EmergencyAlertService.defaultClient();
    await service.dismissNotification(widget.alertData.alert.id);

    await _dismissController.forward();
    print('[SOS Banner] Dismissed: alertId=${widget.alertData.alert.id}');
  }

  void _navigateToDetail() {
    final targetId = widget.alertData.alert.id;

    if (_isNavigating) {
      print('[SOS Banner] Duplicate Navigation Ignored: alertId=$targetId');
      return;
    }

    final currentViewing = EmergencyAlertService.viewingAlertNotifier.value;
    if (currentViewing != null && currentViewing.alert.id == targetId) {
      print('[SOS Banner] Navigation Skipped: SOS Detail already open '
          'for alertId=$targetId');
      return;
    }

    _isNavigating = true;
    print('[SOS Banner] Navigation Started: alertId=$targetId');
    context.push('/sos-alert-detail/$targetId').then((_) {
      _isNavigating = false;
      print('[SOS Banner] Navigation Completed: alertId=$targetId');
    }).catchError((e) {
      _isNavigating = false;
      print('[SOS Banner] Navigation Error: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _dismissController]),
      builder: (context, child) {
        return SlideTransition(
          position: _dismissSlide,
          child: FadeTransition(
            opacity: _dismissFade,
            child: GestureDetector(
              onTap: _isDismissing ? null : _navigateToDetail,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.danger.withValues(alpha: 0.95),
                      Color.lerp(
                        AppTheme.danger,
                        const Color(0xFF991B1B),
                        _pulseController.value * 0.3,
                      )!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.danger.withValues(
                        alpha: 0.3 + _pulseController.value * 0.15,
                      ),
                      blurRadius: 20 + _pulseController.value * 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.emergency_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'EMERGENCY',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.alertData.senderName} needs help',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.alertData.elapsedText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavTabData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavTabData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

class _PremiumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    _NavTabData(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'Home',
    ),
    _NavTabData(
      activeIcon: Icons.map_rounded,
      inactiveIcon: Icons.map_outlined,
      label: 'Map',
    ),
    _NavTabData(
      activeIcon: Icons.notifications_active_rounded,
      inactiveIcon: Icons.notifications_outlined,
      label: 'Alerts',
    ),
    _NavTabData(
      activeIcon: Icons.people_rounded,
      inactiveIcon: Icons.people_outline_rounded,
      label: 'Family',
    ),
    _NavTabData(
      activeIcon: Icons.history_rounded,
      inactiveIcon: Icons.history_outlined,
      label: 'History',
    ),
    _NavTabData(
      activeIcon: Icons.settings_rounded,
      inactiveIcon: Icons.settings_outlined,
      label: 'Settings',
    ),
  ];

  const _PremiumBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A0F1E).withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                width: 0.33,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final isActive = index == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTap(index);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? cs.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isActive
                                  ? _tabs[index].activeIcon
                                  : _tabs[index].inactiveIcon,
                              color: isActive
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.3),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? cs.primary
                                  : cs.onSurface.withValues(alpha: 0.3),
                              letterSpacing: 0.2,
                            ),
                            child: Text(_tabs[index].label),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
