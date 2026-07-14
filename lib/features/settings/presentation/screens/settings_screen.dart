import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/app/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final List<Animation<Offset>> _slideAnims;
  late final AuthService _authService;

  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  bool _locationSharing = true;
  bool _emergencyAlerts = true;
  bool _privacyMode = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService.defaultClient();
    _isDarkMode = true;
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _slideAnims = List.generate(8, (i) {
      final start = (i * 0.08).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Interval(start, end, curve: Curves.easeOutCubic)));
    });
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() { _fadeController.dispose(); _slideController.dispose(); super.dispose(); }

  String get _userName {
    final user = _authService.currentUser;
    if (user == null) return 'Guest User';
    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] != null) return meta['full_name'] as String;
    if (user.email != null) return user.email!.split('@').first;
    return 'Guest User';
  }

  String get _userEmail => _authService.currentUser?.email ?? 'guest@example.com';
  String get _userInitial => _userName == 'Guest User' ? 'G' : _userName.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xFF0F172A), const Color(0xFF0B1120)] : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 4), child: Row(children: [Text('Settings', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)), const Spacer(), _AppBarIcon(icon: Icons.info_outline_rounded, onTap: () => _showAboutDialog(context, theme, cs))]))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[0], child: _buildProfileCard(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[1], child: _buildSectionHeader('Account', theme, cs))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[1], child: _buildAccountSection(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[2], child: _buildSectionHeader('Preferences', theme, cs))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[3], child: _buildPreferencesSection(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[4], child: _buildSectionHeader('Safety', theme, cs))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[5], child: _buildSafetySection(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[6], child: _buildSectionHeader('Support', theme, cs))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[7], child: _buildSupportSection(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[7], child: _buildLogoutButton(theme, cs, isDark))),
                SliverToBoxAdapter(child: _SlideIn(animation: _slideAnims[7], child: Padding(padding: const EdgeInsets.only(top: 20), child: Center(child: Text('GuardianCircle v1.0.0', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.25), fontSize: 12)))))),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme, ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary.withValues(alpha: isDark ? 0.2 : 0.1), cs.tertiary.withValues(alpha: isDark ? 0.15 : 0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.1), width: 1),
                boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: isDark ? 0.2 : 0.06), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, cs.tertiary]), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))]),
                  child: Center(child: Text(_userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24))),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_userName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_userEmail, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('Pro Member', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 11))),
                ])),
                Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurface.withValues(alpha: 0.3)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme, ColorScheme cs) {
    return Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 8), child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5, fontSize: 13)));
  }

  Widget _buildAccountSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(isDark: isDark, children: [
      _SettingsTile(icon: Icons.person_outline_rounded, iconColor: cs.primary, title: 'Edit Profile', subtitle: 'Name, photo, bio', onTap: () => context.push('/profile'), isDark: isDark),
      _SettingsTile(icon: Icons.lock_outline_rounded, iconColor: cs.tertiary, title: 'Change Password', subtitle: 'Update your password', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password change coming soon'))), isDark: isDark, isLast: true),
    ]);
  }

  Widget _buildPreferencesSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(isDark: isDark, children: [
      _SettingsTile(icon: Icons.notifications_outlined, iconColor: const Color(0xFFF59E0B), title: 'Notifications', subtitle: 'Push, email alerts',
        trailing: Switch(value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v), activeThumbColor: Colors.white),
        onTap: () => setState(() => _notificationsEnabled = !_notificationsEnabled), isDark: isDark),
      _SettingsTile(icon: Icons.dark_mode_outlined, iconColor: cs.tertiary, title: 'Dark Mode', subtitle: _isDarkMode ? 'Currently dark' : 'Currently light',
        trailing: Switch(value: _isDarkMode, onChanged: (v) => setState(() => _isDarkMode = v), activeThumbColor: Colors.white),
        onTap: () => setState(() => _isDarkMode = !_isDarkMode), isDark: isDark),
      _SettingsTile(icon: Icons.visibility_outlined, iconColor: cs.secondary, title: 'Privacy Mode', subtitle: 'Hide from others',
        trailing: Switch(value: _privacyMode, onChanged: (v) => setState(() => _privacyMode = v), activeThumbColor: Colors.white),
        onTap: () => setState(() => _privacyMode = !_privacyMode), isDark: isDark, isLast: true),
    ]);
  }

  Widget _buildSafetySection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(isDark: isDark, children: [
      _SettingsTile(icon: Icons.location_on_outlined, iconColor: const Color(0xFF10B981), title: 'Location Sharing', subtitle: 'Share location with family',
        trailing: Switch(value: _locationSharing, onChanged: (v) => setState(() => _locationSharing = v), activeThumbColor: Colors.white),
        onTap: () => setState(() => _locationSharing = !_locationSharing), isDark: isDark),
      _SettingsTile(icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFEF4444), title: 'Emergency Alerts', subtitle: 'SOS notifications',
        trailing: Switch(value: _emergencyAlerts, onChanged: (v) => setState(() => _emergencyAlerts = v), activeThumbColor: Colors.white),
        onTap: () => setState(() => _emergencyAlerts = !_emergencyAlerts), isDark: isDark),
      _SettingsTile(icon: Icons.contacts_outlined, iconColor: cs.primary, title: 'Emergency Contacts', subtitle: 'Manage emergency contacts', onTap: () => context.push('/sos'), isDark: isDark, isLast: true),
    ]);
  }

  Widget _buildSupportSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(isDark: isDark, children: [
      _SettingsTile(icon: Icons.help_outline_rounded, iconColor: const Color(0xFF06B6D4), title: 'Help & Support', subtitle: 'FAQ, contact us', onTap: () => _showHelpDialog(context, theme, cs), isDark: isDark),
      _SettingsTile(icon: Icons.info_outline_rounded, iconColor: cs.primary, title: 'About GuardianCircle', subtitle: 'Version 1.0.0', onTap: () => _showAboutDialog(context, theme, cs), isDark: isDark, isLast: true),
    ]);
  }

  Widget _buildLogoutButton(ThemeData theme, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(context, theme, cs),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.1 : 0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.12), width: 1)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20), const SizedBox(width: 8), Text('Log Out', style: TextStyle(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 15))]),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ThemeData theme, ColorScheme cs) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Log Out'),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)))),
        TextButton(onPressed: () { Navigator.pop(ctx); context.go('/login'); }, child: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444)))),
      ],
    ));
  }

  void _showHelpDialog(BuildContext context, ThemeData theme, ColorScheme cs) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Help & Support'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _HelpItem(icon: Icons.email_outlined, title: 'Email Us', subtitle: 'support@guardiancircle.com', onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening email client...'))); }),
        const SizedBox(height: 12),
        _HelpItem(icon: Icons.chat_outlined, title: 'Live Chat', subtitle: 'Available 24/7', onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to live chat...'))); }),
        const SizedBox(height: 12),
        _HelpItem(icon: Icons.article_outlined, title: 'FAQ', subtitle: 'Common questions', onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening FAQ...'))); }),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: TextStyle(color: cs.primary)))],
    ));
  }

  void _showAboutDialog(BuildContext context, ThemeData theme, ColorScheme cs) {
    showAboutDialog(
      context: context,
      applicationName: 'GuardianCircle',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, cs.secondary]), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
      ),
      children: [const Padding(padding: EdgeInsets.only(top: 16), child: Text('Family safety and location sharing app.'))],
    );
  }

}

class _HelpItem extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _HelpItem({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface, fontSize: 14)), Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)))])),
        ]),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final bool isDark; final List<Widget> children;
  const _GlassSection({required this.isDark, required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(color: cs.surface.withValues(alpha: isDark ? 0.6 : 0.8), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03), blurRadius: 16, offset: const Offset(0, 4))]),
            child: Column(children: children),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color iconColor; final String title; final String subtitle; final VoidCallback onTap; final bool isDark; final bool isLast; final Widget? trailing;
  const _SettingsTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap, required this.isDark, this.isLast = false, this.trailing});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.5))),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)), const SizedBox(height: 1), Text(subtitle, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12))])),
          if (trailing != null) trailing! else Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.2)),
        ]),
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  const _AppBarIcon({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5)), child: Icon(icon, size: 22, color: cs.onSurface.withValues(alpha: 0.6))));
  }
}

class _SlideIn extends StatelessWidget {
  final Animation<Offset> animation; final Widget child;
  const _SlideIn({required this.animation, required this.child});
  @override
  Widget build(BuildContext context) => SlideTransition(position: animation, child: child);
}
