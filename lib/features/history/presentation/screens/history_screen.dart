import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:guardiancircle/shared/widgets/app_bar_icon_button.dart';
import 'package:guardiancircle/shared/widgets/empty_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final StaggeredSlideIns _slideIns;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilter = 0;
  static const _filters = ['All', 'Today', 'This Week', 'This Month'];

  final _events = const [
    _HistoryEvent(
      type: _EventType.arrival,
      memberName: 'Sarah Miller',
      memberColor: Color(0xFFEC4899),
      title: 'Arrived at Home',
      subtitle: '123 Main St, New York, NY',
      time: '10 minutes ago',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.departure,
      memberName: 'James Miller',
      memberColor: Color(0xFF3B82F6),
      title: 'Left Office',
      subtitle: '456 Park Ave, New York, NY',
      time: '35 minutes ago',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.arrival,
      memberName: 'Emma Miller',
      memberColor: Color(0xFF8B5CF6),
      title: 'Arrived at School',
      subtitle: '789 Broadway, New York, NY',
      time: '2 hours ago',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.sos,
      memberName: 'You',
      memberColor: AppTheme.primary,
      title: 'SOS Alert Sent',
      subtitle: 'Emergency alert to all members',
      time: '3 hours ago',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.departure,
      memberName: 'Sarah Miller',
      memberColor: Color(0xFFEC4899),
      title: 'Left Home',
      subtitle: '123 Main St, New York, NY',
      time: '6 hours ago',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.arrival,
      memberName: 'James Miller',
      memberColor: Color(0xFF3B82F6),
      title: 'Arrived at Office',
      subtitle: '456 Park Ave, New York, NY',
      time: '9:15 AM',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.departure,
      memberName: 'Emma Miller',
      memberColor: Color(0xFF8B5CF6),
      title: 'Left Home',
      subtitle: '123 Main St, New York, NY',
      time: '8:30 AM',
      date: 'Today',
    ),
    _HistoryEvent(
      type: _EventType.arrival,
      memberName: 'Sarah Miller',
      memberColor: Color(0xFFEC4899),
      title: 'Arrived at Gym',
      subtitle: '321 Fitness Blvd, New York, NY',
      time: '7:45 AM',
      date: 'Yesterday',
    ),
    _HistoryEvent(
      type: _EventType.sos,
      memberName: 'James Miller',
      memberColor: Color(0xFF3B82F6),
      title: 'SOS Alert Sent',
      subtitle: 'False alarm - resolved',
      time: '4:20 PM',
      date: 'Yesterday',
    ),
    _HistoryEvent(
      type: _EventType.departure,
      memberName: 'You',
      memberColor: AppTheme.primary,
      title: 'Left Coffee Shop',
      subtitle: '88 Bean St, New York, NY',
      time: '2:00 PM',
      date: 'Yesterday',
    ),
    _HistoryEvent(
      type: _EventType.arrival,
      memberName: 'Emma Miller',
      memberColor: Color(0xFF8B5CF6),
      title: 'Arrived at Library',
      subtitle: '555 Book Ln, New York, NY',
      time: '11:00 AM',
      date: 'Yesterday',
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
    _slideIns = StaggeredSlideIns(controller: _slideController, count: 10);
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_HistoryEvent> get _filteredEvents {
    var events = _events;
    if (_searchQuery.isNotEmpty) {
      events = events
          .where(
            (e) =>
                e.memberName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                e.title.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    if (_selectedFilter == 1) {
      events = events.where((e) => e.date == 'Today').toList();
    }
    return events;
  }

  List<String> get _dateGroups =>
      _filteredEvents.map((e) => e.date).toSet().toList();

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
                              'Activity History',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_events.length} events recorded',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        AppBarIconButton(
                          icon: Icons.route_rounded,
                          onTap: () {
                            context.push('/location-history');
                          },
                        ),
                        const SizedBox(width: 6),
                        AppBarIconButton(
                          icon: Icons.file_download_outlined,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(0),
                    child: _buildSearchBar(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(1),
                    child: _buildFilterChips(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(2),
                    child: _buildSummaryBar(cs, isDark),
                  ),
                ),
                for (var di = 0; di < _dateGroups.length; di++) ...[
                  SliverToBoxAdapter(
                    child: SlideInAnimation(
                      animation: _slideIns.get(
                        (di + 3).clamp(0, _slideIns.animations.length - 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          _dateGroups[di],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.45),
                            letterSpacing: 0.5,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dateEvents = _filteredEvents
                            .where((e) => e.date == _dateGroups[di])
                            .toList();
                        return SlideInAnimation(
                          animation: _slideIns.get(
                            (di + index + 3)
                                .clamp(0, _slideIns.animations.length - 1),
                          ),
                          child: _buildEventCard(
                            dateEvents[index],
                            theme,
                            cs,
                            isDark,
                            index,
                            dateEvents.length,
                          ),
                        );
                      },
                      childCount: _filteredEvents
                          .where((e) => e.date == _dateGroups[di])
                          .length,
                    ),
                  ),
                ],
                if (_filteredEvents.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No events found',
                      subtitle: 'Try adjusting your search or filters',
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

  Widget _buildSearchBar(ThemeData theme, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _searchQuery.isNotEmpty
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outline.withValues(alpha: 0.4),
                width: _searchQuery.isNotEmpty ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _searchQuery.isNotEmpty
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search events, members...',
                      hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 14),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, ColorScheme cs, bool isDark) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
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
                  _filters[index],
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

  Widget _buildSummaryBar(ColorScheme cs, bool isDark) {
    final arrivals =
        _filteredEvents.where((e) => e.type == _EventType.arrival).length;
    final departures =
        _filteredEvents.where((e) => e.type == _EventType.departure).length;
    final sos =
        _filteredEvents.where((e) => e.type == _EventType.sos).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.login_rounded,
            count: arrivals,
            label: 'Arrivals',
            color: AppTheme.success,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.logout_rounded,
            count: departures,
            label: 'Departures',
            color: cs.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.warning_amber_rounded,
            count: sos,
            label: 'SOS',
            color: AppTheme.danger,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    _HistoryEvent event,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
    int index,
    int totalForDate,
  ) {
    final isLast = index == totalForDate - 1;
    final typeData = _eventTypeData(event.type, cs);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.title} - ${event.memberName}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeData.color.withValues(alpha: isDark ? 0.15 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: typeData.color.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(typeData.icon, size: 18, color: typeData.color),
                  ),
                  if (!isLast)
                    Container(
                      width: 1.5,
                      height: 20,
                      color: cs.onSurface.withValues(alpha: 0.07),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.12 : 0.02,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  event.memberColor,
                                  event.memberColor.withValues(alpha: 0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: event.memberColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                event.memberName.characters.first,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        event.title,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeData.color.withValues(
                                          alpha: isDark ? 0.15 : 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        typeData.label,
                                        style: TextStyle(
                                          color: typeData.color,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  event.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 12,
                                      color: cs.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      event.memberName,
                                      style: TextStyle(
                                        color: cs.onSurface.withValues(alpha: 0.35),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: cs.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        event.time,
                                        style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.35),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _TypeData _eventTypeData(_EventType type, ColorScheme cs) {
    switch (type) {
      case _EventType.arrival:
        return _TypeData(
          icon: Icons.login_rounded,
          color: AppTheme.success,
          label: 'Arrival',
        );
      case _EventType.departure:
        return _TypeData(
          icon: Icons.logout_rounded,
          color: cs.primary,
          label: 'Departure',
        );
      case _EventType.sos:
        return _TypeData(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.danger,
          label: 'SOS',
        );
    }
  }
}

enum _EventType { arrival, departure, sos }

class _TypeData {
  final IconData icon;
  final Color color;
  final String label;
  const _TypeData({required this.icon, required this.color, required this.label});
}

class _HistoryEvent {
  final _EventType type;
  final String memberName;
  final Color memberColor;
  final String title;
  final String subtitle;
  final String time;
  final String date;

  const _HistoryEvent({
    required this.type,
    required this.memberName,
    required this.memberColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.date,
  });
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: isDark ? 0.45 : 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
