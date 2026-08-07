import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/app/auth_service.dart';
import 'package:guardiancircle/app/profile_state.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/models/self_location_info.dart';
import 'package:guardiancircle/services/activity_service.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/services/location_tracking_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:guardiancircle/shared/widgets/glass_card.dart';
import 'package:guardiancircle/shared/widgets/section_header.dart';
import 'package:guardiancircle/shared/widgets/quick_action_tile.dart';
import 'package:guardiancircle/shared/widgets/activity_tile.dart';
import 'package:guardiancircle/shared/widgets/sos_button.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:guardiancircle/shared/widgets/app_bar_icon_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const Duration _onlineThreshold = Duration(minutes: 5);
  late final AuthService _authService;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final StaggeredSlideIns _slideIns;

  List<FamilyActivityEvent> _recentActivity = [];
  bool _activityLoading = true;
  SelfLocationInfo? _selfLocation;
  bool _locationLoading = true;
  List<_FamilyMember> _familyMembers = [];
  bool _familyLoading = true;

  @override
  void initState() {
    super.initState();
    _authService = AuthService.defaultClient();
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
    _slideIns = StaggeredSlideIns(controller: _slideController, count: 8);
    _fadeController.forward();
    _slideController.forward();
    _loadRecentActivity();
    _loadSelfLocation();
    _loadFamilyCircle();
  }

  Future<void> _loadFamilyCircle() async {
    try {
      final service = FamilyService.defaultClient();
      final families = await service.fetchFamilies();
      if (families.isEmpty) {
        if (!mounted) return;
        setState(() {
          _familyMembers = [];
          _familyLoading = false;
        });
        return;
      }

      final family = families.first;
      final createdBy = family.createdBy;
      final rows = await service.fetchFamilyMembers(family.id);
      final userIds = rows.map((r) => r['user_id'] as String).toList();
      final onlineIds = await _fetchOnlineUserIds(userIds);

      const avatarColors = [
        Color(0xFFEC4899),
        Color(0xFF3B82F6),
        Color(0xFF8B5CF6),
        Color(0xFFF59E0B),
        Color(0xFF10B981),
        Color(0xFFEF4444),
        Color(0xFF06B6D4),
        Color(0xFF8B5CF6),
      ];

      final members = rows.map((row) {
        final profile = service.parseProfile(row);
        final name = profile?.displayName ?? 'Unknown';
        final uid = row['user_id'] as String;
        final isOwner = row['role'] == 'owner' || uid == createdBy;
        return _FamilyMember(
          name: name,
          role: isOwner ? 'Owner' : (row['role'] as String? ?? 'Member'),
          color: avatarColors[name.hashCode.abs() % avatarColors.length],
          photoUrl: profile?.photoUrl,
          isOwner: isOwner,
          isOnline: onlineIds.contains(uid),
          userId: uid,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _familyMembers = members;
        _familyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _familyMembers = [];
        _familyLoading = false;
      });
    }
  }

  Future<Set<String>> _fetchOnlineUserIds(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    try {
      final rows = await SupabaseService.client
          .from('user_locations')
          .select('user_id, updated_at')
          .inFilter('user_id', userIds);
      final now = DateTime.now();
      final online = <String>{};
      for (final row in (rows as List)) {
        final updated = row['updated_at'];
        if (updated == null) continue;
        final lastUpdate = DateTime.tryParse(updated as String)?.toLocal();
        if (lastUpdate == null) continue;
        if (now.difference(lastUpdate) <= _onlineThreshold) {
          online.add(row['user_id'] as String);
        }
      }
      return online;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _loadSelfLocation() async {
    final info = await LocationTrackingService.instance.loadSelfLocationInfo();
    if (!mounted) return;
    setState(() {
      _selfLocation = info;
      _locationLoading = false;
    });
  }

  Future<void> _loadRecentActivity() async {
    try {
      final events =
          await ActivityService.defaultClient().fetchActivityEvents();
      if (!mounted) return;
      setState(() {
        _recentActivity = events;
        _activityLoading = false;
      });
    } catch (e) {
      print('[Activity] Failed to load recent activity: $e');
      if (!mounted) return;
      setState(() => _activityLoading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _userName {
    final p = profileNotifier.value;
    if (p != null && p.name != null && p.name!.isNotEmpty) {
      return p.name!.split(' ').first;
    }
    final user = _authService.currentUser;
    if (user == null) return 'there';
    final meta = user.userMetadata;
    if (meta != null && meta['name'] != null) {
      return (meta['name'] as String).split(' ').first;
    }
    if (user.email != null) return user.email!.split('@').first;
    return 'there';
  }

  String get _userInitial {
    final p = profileNotifier.value;
    if (p != null && p.name != null && p.name!.isNotEmpty) {
      return p.name!.characters.first.toUpperCase();
    }
    final user = _authService.currentUser;
    if (user == null) return '?';
    final meta = user.userMetadata;
    if (meta != null && meta['name'] != null) {
      return (meta['name'] as String).characters.first.toUpperCase();
    }
    if (user.email != null) return user.email!.characters.first.toUpperCase();
    return '?';
  }

  String? get _userPhotoUrl => profileNotifier.value?.photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<AppThemeExtension>() ?? const AppThemeExtension(
      glassBackground: Color(0xFF1E293B), glassBorder: Color(0x14FFFFFF),
      backgroundGradient: [Color(0xFF0F172A), Color(0xFF1E293B)],
      mapOverlayBackground: Color(0xF20F172A), blurSigma: 24.0,
      activePulseColor: Color(0x332563EB), cardShadow: Color(0x4D000000),
      primaryGlow: Color(0x332563EB),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ext.backgroundGradient,
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
                SliverToBoxAdapter(child: _buildAppBar(theme, cs)),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(0),
                    child: _buildWelcomeCard(theme, cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(1),
                    child: _buildLocationCard(theme, cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(2),
                    child: SosButton(
                      onPressed: () => _showSosConfirmation(context, theme),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(3),
                    child: _buildFamilyCard(theme, cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(4),
                    child: const SectionHeader(
                      title: 'Quick Actions',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(5),
                    child: _buildQuickActions(cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(6),
                    child: SectionHeader(
                      title: 'Recent Activity',
                      actionText: 'See All',
                      onAction: () => context.push('/history'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(7),
                    child: _buildRecentActivity(theme),
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

  Widget _buildAppBar(ThemeData theme, ColorScheme cs) {
    return ValueListenableBuilder(
      valueListenable: profileNotifier,
      builder: (_, _, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppBarIconButton(
              icon: Icons.notifications_active_outlined,
              onTap: () => context.push('/notifications'),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.push('/settings'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary, cs.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _userPhotoUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              _userInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _userInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
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

  Widget _buildWelcomeCard(ThemeData theme, ColorScheme cs) {
    final String circleSubtitle;
    final String circleBadgeText;
    final Color circleDotColor;
    final List<BoxShadow>? circleDotShadow;
    if (_familyLoading) {
      circleSubtitle = 'Loading your circle…';
      circleBadgeText = '…';
      circleDotColor = cs.onSurface.withValues(alpha: 0.3);
      circleDotShadow = null;
    } else if (_familyMembers.isEmpty) {
      circleSubtitle = 'No family members yet.';
      circleBadgeText = 'No members';
      circleDotColor = cs.onSurface.withValues(alpha: 0.3);
      circleDotShadow = null;
    } else {
      final online = _familyMembers.where((m) => m.isOnline).length;
      circleSubtitle = '$online of ${_familyMembers.length} members online';
      circleBadgeText = online > 0 ? 'Active' : 'Idle';
      circleDotColor =
          online > 0 ? AppTheme.success : cs.onSurface.withValues(alpha: 0.3);
      circleDotShadow = online > 0
          ? const [BoxShadow(color: Color(0x8010B981), blurRadius: 4)]
          : null;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.2),
                  cs.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.shield_rounded, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your circle is safe',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  circleSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: circleDotColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: circleDotColor,
                    shape: BoxShape.circle,
                    boxShadow: circleDotShadow,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  circleBadgeText,
                  style: TextStyle(
                    color: circleDotColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(ThemeData theme, ColorScheme cs) {
    final isDark = theme.brightness == Brightness.dark;
    final selfLocation = _selfLocation;
    final String pillText;
    final String addressText;
    final String updatedText;
    if (_locationLoading) {
      pillText = 'Loading…';
      addressText = 'Fetching your location…';
      updatedText = 'Updating…';
    } else if (selfLocation == null) {
      pillText = 'Location unavailable';
      addressText = 'Location unavailable';
      updatedText = 'Unavailable';
    } else {
      pillText = selfLocation.area;
      addressText = selfLocation.address;
      updatedText =
          'Updated ${formatActivityTime(selfLocation.position.timestamp)}';
    }
    return GestureDetector(
      onTap: () => context.push('/location-details'),
      child: GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A2744), const Color(0xFF0F1B33)]
                    : [const Color(0xFFE8F0FE), const Color(0xFFD4E4FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 150),
                  painter: _MapGridPainter(
                    color: cs.primary.withValues(alpha: isDark ? 0.06 : 0.08),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'You',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 14, color: cs.primary),
                            const SizedBox(width: 4),
                            Text(
                              pillText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Icon(Icons.place_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        addressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    updatedText,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFamilyCard(ThemeData theme, ColorScheme cs) {
    final onlineCount = _familyMembers.where((m) => m.isOnline).length;

    return GestureDetector(
      onTap: () => context.go('/family'),
      child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Family Circle',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_familyLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Loading…',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$onlineCount/${_familyMembers.length} online',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFamilyMembers(theme, cs),
        ],
      ),
      ),
    );
  }

  Widget _buildFamilyMembers(ThemeData theme, ColorScheme cs) {
    if (_familyLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: cs.primary,
            ),
          ),
        ),
      );
    }

    if (_familyMembers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No family members yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visible = _familyMembers.take(4).toList();
    final hiddenCount = _familyMembers.length - visible.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final member in visible) _buildFamilyMemberTile(theme, cs, member),
        if (hiddenCount > 0) _buildMoreTile(theme, cs, hiddenCount),
      ],
    );
  }

  Widget _buildFamilyMemberTile(
    ThemeData theme,
    ColorScheme cs,
    _FamilyMember member,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    member.color,
                    member.color.withValues(alpha: 0.65),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: member.color.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: (member.photoUrl != null &&
                        member.photoUrl!.isNotEmpty)
                    ? Image.network(
                        member.photoUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _buildMemberInitial(member),
                      )
                    : _buildMemberInitial(member),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: member.isOnline
                      ? AppTheme.success
                      : cs.onSurface.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0A0F1E),
                    width: 3,
                  ),
                  boxShadow: member.isOnline
                      ? const [
                          BoxShadow(
                            color: Color(0x8010B981),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          member.role,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberInitial(_FamilyMember member) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            member.color,
            member.color.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          member.name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreTile(ThemeData theme, ColorScheme cs, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              '+$count',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'More',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: QuickActionTile(
              icon: Icons.share_location_rounded,
              label: 'Share\nLocation',
              color: cs.primary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location shared with your circle')),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: QuickActionTile(
              icon: Icons.chat_bubble_rounded,
              label: 'Family\nChat',
              color: cs.secondary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat coming soon')),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: QuickActionTile(
              icon: Icons.check_circle_outline_rounded,
              label: 'Safe\nCheck-in',
              color: AppTheme.success,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Check-in sent to your circle')),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: QuickActionTile(
              icon: Icons.history_rounded,
              label: 'Location\nHistory',
              color: AppTheme.warning,
              onTap: () => context.push('/history'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    final cs = Theme.of(context).colorScheme;
    if (_activityLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: cs.primary,
            ),
          ),
        ),
      );
    }

    final events = _recentActivity.take(4).toList();
    if (events.isEmpty) {
      return _buildRecentActivityEmpty(theme, cs);
    }

    return Column(
      children: events.map((e) {
        return ActivityTile(
          icon: _activityIcon(e.type),
          iconColor: _activityColor(e.type, cs),
          title: _activityTitle(e),
          subtitle: e.detail,
          time: formatActivityTime(e.timestamp),
          onTap: () => context.push('/history'),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivityEmpty(ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 26,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Text(
            'No recent family activity.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'SOS alerts and new family members will appear here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(FamilyActivityType type) {
    switch (type) {
      case FamilyActivityType.sosCreated:
        return Icons.warning_amber_rounded;
      case FamilyActivityType.sosCancelled:
        return Icons.check_circle_rounded;
      case FamilyActivityType.memberJoined:
        return Icons.person_add_alt_1_rounded;
    }
  }

  Color _activityColor(FamilyActivityType type, ColorScheme cs) {
    switch (type) {
      case FamilyActivityType.sosCreated:
        return AppTheme.danger;
      case FamilyActivityType.sosCancelled:
        return AppTheme.success;
      case FamilyActivityType.memberJoined:
        return cs.primary;
    }
  }

  String _activityTitle(FamilyActivityEvent event) {
    switch (event.type) {
      case FamilyActivityType.sosCreated:
        return '${event.memberName} sent an SOS alert';
      case FamilyActivityType.sosCancelled:
        return '${event.memberName} cancelled an SOS alert';
      case FamilyActivityType.memberJoined:
        return '${event.memberName} joined the family';
    }
  }

  void _showSosConfirmation(BuildContext context, ThemeData theme) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppTheme.danger,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Send SOS Alert?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All family members will be notified of your emergency and your live location will be shared.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/sos');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.danger, Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.danger.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Send SOS Alert',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _FamilyMember {
  final String name;
  final String role;
  final Color color;
  final String? photoUrl;
  final bool isOwner;
  final bool isOnline;
  final String userId;

  const _FamilyMember({
    required this.name,
    required this.role,
    required this.color,
    this.photoUrl,
    required this.isOwner,
    required this.isOnline,
    required this.userId,
  });
}

class _MapGridPainter extends CustomPainter {
  final Color color;
  _MapGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
