import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';


class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _PremiumBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
      ),
    );
  }
}

class _NavTabData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _NavTabData({required this.activeIcon, required this.inactiveIcon, required this.label});
}

class _PremiumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomNavBar({required this.currentIndex, required this.onTap});

  static const _tabs = [
    _NavTabData(activeIcon: Icons.home_rounded, inactiveIcon: Icons.home_outlined, label: 'Home'),
    _NavTabData(activeIcon: Icons.notifications_active_rounded, inactiveIcon: Icons.notifications_outlined, label: 'Alerts'),
    _NavTabData(activeIcon: Icons.people_rounded, inactiveIcon: Icons.people_outline_rounded, label: 'Family'),
    _NavTabData(activeIcon: Icons.history_rounded, inactiveIcon: Icons.history_outlined, label: 'History'),
    _NavTabData(activeIcon: Icons.settings_rounded, inactiveIcon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                width: 0.33,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
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
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            decoration: BoxDecoration(
                              color: isActive ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AnimatedScale(
                              scale: isActive ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                              child: Icon(
                                isActive ? _tabs[index].activeIcon : _tabs[index].inactiveIcon,
                                color: isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 280),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
                              letterSpacing: 0.1,
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
