import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final List<Animation<Offset>> _slideAnims;
  final _searchController = TextEditingController();
  bool _isSearchActive = false;
  String _searchQuery = '';

  final _members = const [
    _FamilyMember(name: 'Sarah Miller', role: 'Mom', color: Color(0xFFEC4899), isOnline: true, battery: 87, distance: '0.3 mi', lastSeen: 'Just now'),
    _FamilyMember(name: 'James Miller', role: 'Dad', color: Color(0xFF3B82F6), isOnline: true, battery: 62, distance: '1.2 mi', lastSeen: '5m ago'),
    _FamilyMember(name: 'Emma Miller', role: 'Sister', color: Color(0xFF8B5CF6), isOnline: false, battery: 15, distance: '4.7 mi', lastSeen: '1h ago'),
    _FamilyMember(name: 'You', role: 'Me', color: AppTheme.primary, isOnline: true, battery: 94, distance: '—', lastSeen: 'Just now'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _slideAnims = List.generate(4, (i) {
      final start = (i * 0.1).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Interval(start, end, curve: Curves.easeOutCubic)));
    });
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() { _fadeController.dispose(); _slideController.dispose(); _searchController.dispose(); super.dispose(); }

  List<_FamilyMember> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase()) || m.role.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onlineCount = _members.where((m) => m.isOnline).length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xFF0F172A), const Color(0xFF0B1120)] : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildAppBar(theme, cs, onlineCount)),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[0], child: _buildSearchBar(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[1], child: _buildStatsRow(cs, isDark, onlineCount))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[1], child: Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Members', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), Text('${_filteredMembers.length} total', style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.45)))])))),
                SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                  final member = _filteredMembers[index];
                  return _SlideIn(animation: _slideAnims[index.clamp(0, _slideAnims.length - 1)], child: _buildMemberCard(member, theme, cs, isDark));
                }, childCount: _filteredMembers.length)),
                if (_filteredMembers.isEmpty) SliverToBoxAdapter(child: _buildEmptyState(theme, cs)),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[2], child: _buildActionButtons(cs, isDark))),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, ColorScheme cs, int onlineCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Family Circle', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text('$onlineCount of ${_members.length} members online', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.45))),
        ]),
        const Spacer(),
        _AppBarIcon(icon: Icons.person_add_alt_1_rounded, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add member coming soon')))),
      ]),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: isDark ? 0.6 : 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isSearchActive ? cs.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06), width: _isSearchActive ? 1.5 : 0.5),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, size: 20, color: _isSearchActive ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onTap: () => setState(() => _isSearchActive = true),
                  onEditingComplete: () => setState(() { _isSearchActive = false; FocusScope.of(context).unfocus(); }),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(hintText: 'Search family members...', hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.35), fontWeight: FontWeight.w400), border: InputBorder.none, contentPadding: const EdgeInsets.only(top: 14)),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchController.clear(); setState(() { _searchQuery = ''; _isSearchActive = false; }); FocusScope.of(context).unfocus(); },
                  child: Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.5))),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ColorScheme cs, bool isDark, int onlineCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(children: [
        _StatChip(icon: Icons.circle, iconColor: const Color(0xFF10B981), label: '$onlineCount Online', isDark: isDark),
        const SizedBox(width: 8),
        _StatChip(icon: Icons.battery_std_rounded, iconColor: const Color(0xFFF59E0B), label: 'Avg 65%', isDark: isDark),
        const SizedBox(width: 8),
        _StatChip(icon: Icons.location_on_rounded, iconColor: cs.primary, label: '2.1 mi avg', isDark: isDark),
      ]),
    );
  }

  Widget _buildMemberCard(_FamilyMember member, ThemeData theme, ColorScheme cs, bool isDark) {
    final batteryColor = member.battery > 50 ? const Color(0xFF10B981) : member.battery > 20 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing ${member.name}\'s details'))); },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.6 : 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Stack(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [member.color, member.color.withValues(alpha: 0.65)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: member.color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: Center(child: Text(member.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5))),
                  ),
                  Positioned(right: 0, bottom: 0, child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: member.isOnline ? const Color(0xFF10B981) : cs.onSurface.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 2.5),
                      boxShadow: member.isOnline ? [const BoxShadow(color: Color(0x8010B981), blurRadius: 6)] : null,
                    ),
                  )),
                ]),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(member.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                    if (member.name == 'You') ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cs.primary.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(6)), child: Text('You', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 9)))],
                  ]),
                  const SizedBox(height: 3),
                  Text(member.role, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.45))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: member.isOnline ? const Color(0xFF10B981) : cs.onSurface.withValues(alpha: 0.2), shape: BoxShape.circle, boxShadow: member.isOnline ? [const BoxShadow(color: Color(0x8010B981), blurRadius: 4)] : null)),
                    const SizedBox(width: 5),
                    Text(member.isOnline ? 'Online' : 'Offline', style: TextStyle(color: member.isOnline ? const Color(0xFF10B981) : cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w500, fontSize: 11)),
                    const SizedBox(width: 12),
                    Icon(Icons.battery_std_rounded, size: 14, color: batteryColor),
                    const SizedBox(width: 3),
                    Text('${member.battery}%', style: TextStyle(color: batteryColor, fontWeight: FontWeight.w600, fontSize: 11)),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on_rounded, size: 13, color: cs.primary.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text(member.distance, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w500, fontSize: 11)),
                  ]),
                ])),
                Container(width: 32, height: 32, decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.search_off_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.15)),
        const SizedBox(height: 12),
        Text('No members found', style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 4),
        Text('Try a different search', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.3))),
      ]),
    );
  }

  Widget _buildActionButtons(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        Expanded(child: _ActionCard(icon: Icons.person_add_rounded, label: 'Invite\nMember', gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.8)]), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite link copied!'))))),
        const SizedBox(width: 14),
        Expanded(child: _ActionCard(icon: Icons.group_add_rounded, label: 'Add to\nCircle', gradient: LinearGradient(colors: [cs.tertiary, cs.tertiary.withValues(alpha: 0.8)]), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add to circle coming soon'))))),
      ]),
    );
  }
}

class _FamilyMember {
  final String name; final String role; final Color color; final bool isOnline; final int battery; final String distance; final String lastSeen;
  const _FamilyMember({required this.name, required this.role, required this.color, required this.isOnline, required this.battery, required this.distance, required this.lastSeen});
}

class _StatChip extends StatelessWidget {
  final IconData icon; final Color iconColor; final String label; final bool isDark;
  const _StatChip({required this.icon, required this.iconColor, required this.label, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.surface.withValues(alpha: isDark ? 0.5 : 0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: iconColor), const SizedBox(width: 5), Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: cs.onSurface.withValues(alpha: 0.7)))]),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  const _AppBarIcon({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5)), child: Icon(icon, size: 22, color: cs.onSurface.withValues(alpha: 0.6))),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String label; final Gradient gradient; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.gradient, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Stack(children: [
          Positioned(right: -10, top: -10, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)))),
          Positioned(right: 20, bottom: -15, child: Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, height: 1.2)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SlideIn extends StatelessWidget {
  final Animation<Offset> animation; final Widget child;
  const _SlideIn({required this.animation, required this.child});
  @override
  Widget build(BuildContext context) => SlideTransition(position: animation, child: child);
}
