import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/services/emergency_alert_service.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:guardiancircle/shared/widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final StaggeredSlideIns _slideIns;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideIns = StaggeredSlideIns(controller: _slideController, count: 6);
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ext?.backgroundGradient ??
                (isDark
                    ? [const Color(0xFF0A0F1E), const Color(0xFF060A14)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)]),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ValueListenableBuilder<List<EmergencyAlertWithSender>>(
              valueListenable: EmergencyAlertService.activeAlertsNotifier,
              builder: (context, alerts, _) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alerts',
                                  style:
                                      theme.textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${alerts.length} active',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (alerts.isEmpty)
                      const SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'No notifications',
                          subtitle: 'You\'re all caught up!',
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final alertData = alerts[index];
                            return SlideInAnimation(
                              animation: _slideIns.get(
                                (index + 1).clamp(
                                  0,
                                  _slideIns.animations.length - 1,
                                ),
                              ),
                              child: _buildNotificationCard(
                                alertData,
                                theme,
                                cs,
                                isDark,
                              ),
                            );
                          },
                          childCount: alerts.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    EmergencyAlertWithSender alertData,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    final isActive = alertData.alert.isActive;
    final icon =
        isActive ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
    final color = isActive ? AppTheme.danger : AppTheme.success;
    final title = isActive ? 'SOS Alert Active' : 'SOS Alert Cancelled';
    final subtitle = '${alertData.senderName} sent an emergency alert';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/sos-alert-detail/${alertData.alert.id}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? cs.primary.withValues(alpha: isDark ? 0.08 : 0.05)
              : cs.surface.withValues(alpha: isDark ? 0.45 : 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? cs.primary.withValues(alpha: 0.15)
                : cs.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alertData.elapsedText,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.25),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}
