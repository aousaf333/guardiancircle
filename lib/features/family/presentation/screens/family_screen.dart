import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/models/family_model.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:guardiancircle/shared/widgets/app_bar_icon_button.dart';
import 'package:guardiancircle/shared/widgets/empty_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final StaggeredSlideIns _slideIns;
  final _searchController = TextEditingController();
  final _familyService = FamilyService.defaultClient();
  bool _isSearchActive = false;
  String _searchQuery = '';
  bool _isLoadingFamilies = true;
  String? _familiesError;

  List<FamilyModel> _families = [];
  String? _selectedFamilyId;
  List<_FamilyMember> _members = [];
  bool _isLoadingMembers = false;
  String? _membersError;

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
    _slideIns = StaggeredSlideIns(controller: _slideController, count: 7);
    _fadeController.forward();
    _slideController.forward();
    _fetchFamilies();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_FamilyMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members
        .where(
          (m) =>
              m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              m.role.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Future<void> _fetchFamilies() async {
    setState(() {
      _isLoadingFamilies = true;
      _familiesError = null;
    });
    try {
      final families = await _familyService.fetchFamilies();
      if (mounted) {
        setState(() {
          _families = families;
          _isLoadingFamilies = false;
          if (_selectedFamilyId == null && families.isNotEmpty) {
            _selectedFamilyId = families.first.id;
          }
        });
        if (_selectedFamilyId != null) {
          await _fetchMembers();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _familiesError = e.toString();
          _isLoadingFamilies = false;
        });
      }
    }
  }

  Future<void> _fetchMembers() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) return;
    setState(() {
      _isLoadingMembers = true;
      _membersError = null;
    });
    try {
      final rows = await _familyService.fetchFamilyMembers(familyId);

      print('[FamilyScreen] Current auth uid: '
          '${Supabase.instance.client.auth.currentUser?.id}');
      print('[FamilyScreen] Current family id: $familyId');
      print('[FamilyScreen] Family member rows loaded: ${rows.length}');

      final family = _families.cast<FamilyModel?>().firstWhere(
            (f) => f?.id == familyId,
            orElse: () => null,
          );
      final createdBy = family?.createdBy;

      final members = rows.map((row) {
        final profile = _familyService.parseProfile(row);
        final name = profile?.displayName ?? 'Unknown';
        final email = profile?.email ?? '';
        final isOwner =
            row['role'] == 'owner' || row['user_id'] == createdBy;
        final avatarColors = [
          const Color(0xFFEC4899),
          const Color(0xFF3B82F6),
          const Color(0xFF8B5CF6),
          const Color(0xFFF59E0B),
          const Color(0xFF10B981),
          const Color(0xFFEF4444),
          const Color(0xFF06B6D4),
          const Color(0xFF8B5CF6),
        ];
        final colorIndex = name.hashCode.abs() % avatarColors.length;
        return _FamilyMember(
          name: name,
          email: email,
          role: isOwner ? 'Owner' : (row['role'] as String? ?? 'Member'),
          color: avatarColors[colorIndex],
          photoUrl: profile?.photoUrl,
          isOwner: isOwner,
          userId: row['user_id'] as String,
        );
      }).toList();

      print('[FamilyScreen] User IDs loaded: '
          '${members.map((m) => m.userId).toList()}');
      print('[FamilyScreen] Profiles loaded: ${members.length}');
      print('[FamilyScreen] Members displayed: ${members.length}');

      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _membersError = e.toString();
          _isLoadingMembers = false;
        });
      }
    }
  }

  void _selectFamily(String familyId) {
    if (_selectedFamilyId == familyId) return;
    setState(() => _selectedFamilyId = familyId);
    _fetchMembers();
  }

  Future<void> _shareInviteCode(FamilyModel family) async {
    String? code = family.inviteCode;

    if (code == null || code.isEmpty) {
      try {
        code = await _familyService.generateAndSaveInviteCode(family.id);
        if (mounted) {
          setState(() {
            final index = _families.indexWhere((f) => f.id == family.id);
            if (index != -1) {
              _families[index] = _families[index].copyWith(inviteCode: code);
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate invite code: $e'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return;
      }
    }

    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code copied.')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();
    final memberCount = _members.length;

    return Scaffold(
      floatingActionButton: ScaleOnTap(
        onTap: () => _showCreateFamilyDialog(context, theme, cs),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
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
                  child:                 _buildAppBar(theme, cs, memberCount),
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
                    child: _buildStatsRow(cs, isDark, memberCount),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(2),
                    child: _buildFamiliesSection(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(3),
                    child: _buildInviteCodeSection(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Members',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _selectedFamilyId == null
                                ? '0 total'
                                : '${_filteredMembers.length} total',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isLoadingMembers)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_membersError != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppTheme.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Failed to load members',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _membersError!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _fetchMembers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_selectedFamilyId == null || _members.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.group_off_rounded,
                      title: _selectedFamilyId == null
                          ? 'Select a family'
                          : 'No members yet',
                      subtitle: _selectedFamilyId == null
                          ? 'Tap a family above to view members'
                          : 'Invite members to get started',
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final member = _filteredMembers[index];
                        return SlideInAnimation(
                          animation: _slideIns.get(
                            index.clamp(0, _slideIns.animations.length - 1),
                          ),
                          child: _buildMemberCard(member, theme, cs, isDark),
                        );
                      },
                      childCount: _filteredMembers.length,
                    ),
                  ),
                if (_selectedFamilyId != null &&
                    !_isLoadingMembers &&
                    _membersError == null &&
                    _filteredMembers.isEmpty &&
                    _searchQuery.isNotEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No members found',
                      subtitle: 'Try a different search',
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(5),
                    child: _buildActionButtons(cs, isDark),
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

  Widget _buildAppBar(ThemeData theme, ColorScheme cs, int memberCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Family Circle',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const Spacer(),
          AppBarIconButton(
            icon: Icons.person_add_alt_1_rounded,
            onTap: () => _showInviteDialog(context, theme, cs),
          ),
        ],
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
                color: _isSearchActive
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outline.withValues(alpha: 0.4),
                width: _isSearchActive ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _isSearchActive
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onTap: () => setState(() => _isSearchActive = true),
                    onEditingComplete: () {
                      setState(() {
                        _isSearchActive = false;
                        FocusScope.of(context).unfocus();
                      });
                    },
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search family members...',
                      hintStyle: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w400,
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
                      setState(() {
                        _searchQuery = '';
                        _isSearchActive = false;
                      });
                      FocusScope.of(context).unfocus();
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

  Widget _buildStatsRow(ColorScheme cs, bool isDark, int memberCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.group_rounded,
            iconColor: cs.primary,
            label: '$memberCount ${memberCount == 1 ? 'Member' : 'Members'}',
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.family_restroom_rounded,
            iconColor: AppTheme.success,
            label: '${_families.length} ${_families.length == 1 ? 'Family' : 'Families'}',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFamiliesSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Families',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_families.length} total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingFamilies)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cs.primary,
                  ),
                ),
              ),
            )
          else if (_familiesError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppTheme.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Failed to load families',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _familiesError!,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchFamilies,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_families.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.35 : 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.family_restroom_rounded,
                    size: 28,
                    color: cs.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No families yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap + to create your first family',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_families.length, (i) {
              final family = _families[i];
              final isOwner = family.createdBy == Supabase.instance.client.auth.currentUser?.id;
              final isSelected = family.id == _selectedFamilyId;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _selectFamily(family.id);
                },
                child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(
                          alpha: isDark ? 0.55 : 0.75,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.6)
                              : cs.outline.withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary,
                                  cs.primary.withValues(alpha: 0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                family.name.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  family.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (isOwner && family.inviteCode != null && family.inviteCode!.isNotEmpty)
                                  Text(
                                    'Code: ${family.inviteCode}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                      color: cs.primary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                const SizedBox(height: 1),
                                Text(
                                  'Created ${_formatDate(family.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface.withValues(alpha: 0.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.25),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInviteCodeSection(ThemeData theme, ColorScheme cs, bool isDark) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    final ownedFamilies =
        _families.where((f) => f.createdBy == userId).toList();
    if (ownedFamilies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite Code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...ownedFamilies.map((family) {
            final code = family.inviteCode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(
                        alpha: isDark ? 0.55 : 0.75,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.vpn_key_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              family.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(
                              alpha: isDark ? 0.1 : 0.05,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            (code != null && code.isNotEmpty)
                                ? code
                                : 'TAP TO GENERATE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _shareInviteCode(family),
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text('Share Invite Code'),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    _FamilyMember member,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/member-details', extra: {
          'name': member.name,
          'role': member.role,
          'color': member.color,
          'isOnline': false,
          'battery': 0,
          'distance': '—',
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.75),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: member.isOwner
                      ? cs.primary.withValues(alpha: 0.4)
                      : cs.outline.withValues(alpha: 0.3),
                  width: member.isOwner ? 1.0 : 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      member.photoUrl != null && member.photoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                member.photoUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _buildPlaceholderAvatar(member, cs),
                              ),
                            )
                          : _buildPlaceholderAvatar(member, cs),
                      if (member.isOwner)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.warning,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF111827)
                                    : Colors.white,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (member.isOwner) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(
                                    alpha: isDark ? 0.2 : 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Owner',
                                  style: TextStyle(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (member.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            member.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          member.role,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(_FamilyMember member, ColorScheme cs) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            member.color,
            member.color.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: member.color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          member.name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme cs, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.person_add_rounded,
              label: 'Invite\nMember',
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
              ),
              onTap: () => _showInviteDialog(context, theme, cs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.group_add_rounded,
              label: 'Add to\nCircle',
              gradient: LinearGradient(
                colors: [cs.tertiary, cs.tertiary.withValues(alpha: 0.8)],
              ),
              onTap: () => _showAddDialog(context, theme, cs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.login_rounded,
              label: 'Join\nFamily',
              gradient: LinearGradient(
                colors: [AppTheme.success, AppTheme.success.withValues(alpha: 0.8)],
              ),
              onTap: () => _showJoinFamilyDialog(context, theme, cs),
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, ThemeData theme, ColorScheme cs) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Invite Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send an invitation to join your family circle.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    emailController.text.isNotEmpty
                        ? 'Invitation sent to ${emailController.text}'
                        : 'Please enter an email address',
                  ),
                ),
              );
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, ThemeData theme, ColorScheme cs) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Add to Circle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add a family member by their name or phone number.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Name or phone number',
                prefixIcon: Icon(Icons.person_add_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    nameController.text.isNotEmpty
                        ? '${nameController.text} added to your circle'
                        : 'Please enter a name or phone number',
                  ),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCreateFamilyDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final familyNameController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Create Family'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Give your new family circle a name.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: familyNameController,
                textCapitalization: TextCapitalization.words,
                enabled: !isCreating,
                decoration: const InputDecoration(
                  hintText: 'Family name',
                  prefixIcon: Icon(Icons.family_restroom_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            TextButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = familyNameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a family name'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        final family = await _familyService.createFamily(name);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _fetchFamilies();
                        setState(() => _selectedFamilyId = family.id);
                        await _fetchMembers();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Family "$name" created successfully',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isCreating = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to create family: $e',
                              ),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinFamilyDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final codeController = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Join Family'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter an invite code to join an existing family.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
                enabled: !isJoining,
                decoration: InputDecoration(
                  hintText: 'XXXXXXXX',
                  counterText: '',
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  filled: true,
                  fillColor: cs.surface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isJoining ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ),
            TextButton(
              onPressed: isJoining
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter an invite code'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isJoining = true);

                      try {
                        final family = await _familyService.joinFamily(code);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _fetchFamilies();
                        setState(() => _selectedFamilyId = family.id);
                        await _fetchMembers();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Joined "${family.name}" successfully',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isJoining = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      }
                    },
              child: isJoining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyMember {
  final String name;
  final String email;
  final String role;
  final Color color;
  final String? photoUrl;
  final bool isOwner;
  final String userId;

  const _FamilyMember({
    required this.name,
    required this.email,
    required this.role,
    required this.color,
    this.photoUrl,
    required this.isOwner,
    required this.userId,
  });
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDark;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.45 : 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -15,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
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
}
