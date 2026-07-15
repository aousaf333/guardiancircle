import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
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
  int _selectedFilter = 0;

  final _notifications = [
    _NotificationItem(
      icon: Icons.warning_amber_rounded,
      color: AppTheme.danger,
      title: 'SOS Alert Triggered',
      subtitle: 'James sent an emergency alert',
      time: '2 min ago',
      isRead: false,
      type: 'alert',
    ),
    _NotificationItem(
      icon: Icons.location_on_rounded,
      color: AppTheme.success,
      title: 'Sarah arrived home',
      subtitle: '123 Main St, New York',
      time: '10 min ago',
      isRead: false,
      type: 'arrival',
    ),
    _NotificationItem(
      icon: Icons.login_rounded,
      color: AppTheme.primary,
      title: 'Emma left school',
      subtitle: '789 Broadway, New York',
      time: '30 min ago',
      isRead: false,
      type: 'departure',
    ),
    _NotificationItem(
      icon: Icons.person_add_rounded,
      color: AppTheme.tertiary,
      title: 'New family member',
      subtitle: 'David joined your circle',
      time: '1h ago',
      isRead: true,
      type: 'invite',
    ),
    _NotificationItem(
      icon: Icons.battery_alert_rounded,
      color: AppTheme.warning,
      title: 'Low battery warning',
      subtitle: 'Emma\'s phone at 15%',
      time: '1h ago',
      isRead: true,
      type: 'alert',
    ),
    _NotificationItem(
      icon: Icons.check_circle_rounded,
      color: AppTheme.success,
      title: 'Safe check-in received',
      subtitle: 'James checked in at Central Park',
      time: '2h ago',
      isRead: true,
      type: 'arrival',
    ),
    _NotificationItem(
      icon: Icons.location_off_rounded,
      color: const Color(0xFF64748B),
      title: 'Location sharing paused',
      subtitle: 'Emma paused location sharing',
      time: '3h ago',
      isRead: true,
      type: 'alert',
    ),
    _NotificationItem(
      icon: Icons.login_rounded,
      color: const Color(0xFFEC4899),
      title: 'Sarah left gym',
      subtitle: '321 Fitness Blvd, New York',
      time: '4h ago',
      isRead: true,
      type: 'departure',
    ),
  ];

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

  List<_NotificationItem> get _filteredNotifications {
    if (_selectedFilter == 0) return _notifications;
    if (_selectedFilter == 1) {
      return _notifications.where((n) => n.type == 'alert').toList();
    }
    if (_selectedFilter == 2) {
      return _notifications.where((n) => n.type == 'arrival').toList();
    }
    return _notifications.where((n) => n.type == 'invite').toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

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
            child: CustomScrollView(
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
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_unreadCount unread',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_unreadCount > 0)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                for (var n in _notifications) {
                                  n.isRead = true;
                                }
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('All marked as read')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(0),
                    child: _buildFilterChips(cs, isDark),
                  ),
                ),
                if (_filteredNotifications.isEmpty)
                  SliverToBoxAdapter(
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
                        final notification = _filteredNotifications[index];
                        return SlideInAnimation(
                          animation: _slideIns.get(
                            (index + 1).clamp(
                              0,
                              _slideIns.animations.length - 1,
                            ),
                          ),
                          child: _buildNotificationCard(
                            notification,
                            theme,
                            cs,
                            isDark,
                          ),
                        );
                      },
                      childCount: _filteredNotifications.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme cs, bool isDark) {
    final filters = ['All', 'Alerts', 'Arrivals', 'Invites'];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedFilter == index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedFilter = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary
                    : cs.surface.withValues(alpha: isDark ? 0.5 : 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? cs.primary
                      : cs.outline.withValues(alpha: 0.5),
                  width: 0.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  filters[index],
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    _NotificationItem notification,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => notification.isRead = true);
        context.push('/notification-details', extra: {
          'icon': notification.icon,
          'color': notification.color,
          'title': notification.title,
          'subtitle': notification.subtitle,
          'time': notification.time,
          'type': notification.type,
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? cs.surface.withValues(alpha: isDark ? 0.45 : 0.65)
              : cs.primary.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? cs.outline.withValues(alpha: 0.3)
                : cs.primary.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notification.color.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 22,
                  ),
                ),
                if (!notification.isRead)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: notification.isRead
                          ? cs.onSurface.withValues(alpha: 0.65)
                          : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.time,
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

class _NotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  bool isRead;
  final String type;

  _NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isRead,
    required this.type,
  });
}
