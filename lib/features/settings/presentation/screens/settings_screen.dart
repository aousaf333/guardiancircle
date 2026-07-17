import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/app/auth_service.dart';
import 'package:guardiancircle/app/profile_state.dart';
import 'package:guardiancircle/app/theme_state.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/services/privacy_settings_service.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:guardiancircle/shared/widgets/app_bar_icon_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final StaggeredSlideIns _slideIns;
  late final AuthService _authService;
  late final PrivacySettingsService _privacyService;

  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  bool _locationSharing = true;
  bool _emergencyAlerts = true;
  bool _privacyMode = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService.defaultClient();
    _privacyService = PrivacySettingsService.defaultClient();
    _isDarkMode = themeNotifier.value == ThemeMode.dark;
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
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final settings = await _privacyService.fetchSettings();
      if (mounted) {
        setState(() {
          _locationSharing = settings.locationSharing;
          _privacyMode = settings.invisibleMode;
          _notificationsEnabled = settings.notificationsEnabled;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Failed to load privacy settings: $e');
    }
  }

  Future<void> _savePrivacySettings() async {
    final settings = PrivacySettingsModel(
      locationSharing: _locationSharing,
      invisibleMode: _privacyMode,
      notificationsEnabled: _notificationsEnabled,
    );
    try {
      debugPrint('[Settings] Saving privacy settings – invisible_mode=${settings.invisibleMode}');
      await _privacyService.saveSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Settings] Failed to save privacy settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String get _userName {
    final p = profileNotifier.value;
    if (p != null && p.name != null && p.name!.isNotEmpty) {
      return p.name!;
    }
    final user = _authService.currentUser;
    if (user == null) return 'Guest User';
    final meta = user.userMetadata;
    if (meta != null && meta['name'] != null) {
      return meta['name'] as String;
    }
    if (user.email != null) return user.email!.split('@').first;
    return 'Guest User';
  }

  String get _userEmail =>
      _authService.currentUser?.email ?? 'guest@example.com';
  String get _userInitial =>
      _userName == 'Guest User' ? 'G' : _userName.characters.first.toUpperCase();
  String? get _userPhotoUrl => profileNotifier.value?.photoUrl;

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
                        Text(
                          'Settings',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        AppBarIconButton(
                          icon: Icons.info_outline_rounded,
                          onTap: () => _showAboutDialog(context, theme, cs),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(0),
                    child: _buildProfileCard(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(1),
                    child: _buildSectionHeader('Account', cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(2),
                    child: _buildAccountSection(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(3),
                    child: _buildSectionHeader('Preferences', cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(4),
                    child: _buildPreferencesSection(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(5),
                    child: _buildSectionHeader('Safety', cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(6),
                    child: _buildSafetySection(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(7),
                    child: _buildSectionHeader('Support', cs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(8),
                    child: _buildSupportSection(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(9),
                    child: _buildLogoutButton(theme, cs, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'GuardianCircle v1.0.0',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          fontSize: 12,
                        ),
                      ),
                    ),
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

  Widget _buildProfileCard(ThemeData theme, ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: ValueListenableBuilder(
        valueListenable: profileNotifier,
        builder: (_, _, _) => Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                      cs.tertiary.withValues(alpha: isDark ? 0.12 : 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'profile-avatar',
                      child: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                _userPhotoUrl!,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [cs.primary, cs.tertiary],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _userInitial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [cs.primary, cs.tertiary],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _userInitial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userEmail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(
                              alpha: isDark ? 0.15 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Pro Member',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.35),
          letterSpacing: 0.5,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildAccountSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(
      isDark: isDark,
      children: [
        _SettingsTile(
          icon: Icons.person_outline_rounded,
          iconColor: cs.primary,
          title: 'Edit Profile',
          subtitle: 'Name, photo, bio',
          onTap: () => context.push('/profile'),
        ),
        _SettingsTile(
          icon: Icons.lock_outline_rounded,
          iconColor: cs.tertiary,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () => _showChangePasswordDialog(context, theme, cs),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    return _GlassSection(
      isDark: isDark,
      children: [
        _SettingsTile(
          icon: Icons.notifications_outlined,
          iconColor: AppTheme.warning,
          title: 'Notifications',
          subtitle: 'Push, email alerts',
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              _savePrivacySettings();
            },
          ),
          onTap: () {
            setState(() => _notificationsEnabled = !_notificationsEnabled);
            _savePrivacySettings();
          },
        ),
        _SettingsTile(
          icon: Icons.dark_mode_outlined,
          iconColor: cs.tertiary,
          title: 'Dark Mode',
          subtitle: _isDarkMode ? 'Currently dark' : 'Currently light',
          trailing: Switch(
            value: _isDarkMode,
            onChanged: (v) {
              setState(() => _isDarkMode = v);
              themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          onTap: () {
            setState(() => _isDarkMode = !_isDarkMode);
            themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
          },
        ),
        _SettingsTile(
          icon: Icons.visibility_outlined,
          iconColor: cs.secondary,
          title: 'Privacy Mode',
          subtitle: 'Hide from others',
          trailing: Switch(
            value: _privacyMode,
            onChanged: (v) {
              setState(() => _privacyMode = v);
              _savePrivacySettings();
            },
          ),
          onTap: () {
            setState(() => _privacyMode = !_privacyMode);
            _savePrivacySettings();
          },
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildSafetySection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(
      isDark: isDark,
      children: [
        _SettingsTile(
          icon: Icons.location_on_outlined,
          iconColor: AppTheme.success,
          title: 'Location Sharing',
          subtitle: 'Share location with family',
          trailing: Switch(
            value: _locationSharing,
            onChanged: (v) {
              setState(() => _locationSharing = v);
              _savePrivacySettings();
            },
          ),
          onTap: () {
            setState(() => _locationSharing = !_locationSharing);
            _savePrivacySettings();
          },
        ),
        _SettingsTile(
          icon: Icons.warning_amber_rounded,
          iconColor: AppTheme.danger,
          title: 'Emergency Alerts',
          subtitle: 'SOS notifications',
          trailing: Switch(
            value: _emergencyAlerts,
            onChanged: (v) => setState(() => _emergencyAlerts = v),
          ),
          onTap: () =>
              setState(() => _emergencyAlerts = !_emergencyAlerts),
        ),
        _SettingsTile(
          icon: Icons.contacts_outlined,
          iconColor: cs.primary,
          title: 'Emergency Contacts',
          subtitle: 'Manage emergency contacts',
          onTap: () => context.push('/emergency-contacts'),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildSupportSection(ThemeData theme, ColorScheme cs, bool isDark) {
    return _GlassSection(
      isDark: isDark,
      children: [
        _SettingsTile(
          icon: Icons.help_outline_rounded,
          iconColor: AppTheme.accent,
          title: 'Help & Support',
          subtitle: 'FAQ, contact us',
          onTap: () => _showHelpDialog(context, theme, cs),
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          iconColor: cs.secondary,
          title: 'Privacy Policy',
          subtitle: 'How we protect your data',
          onTap: () => _showPrivacyDialog(context, theme, cs),
        ),
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          iconColor: cs.primary,
          title: 'About GuardianCircle',
          subtitle: 'Version 1.0.0',
          onTap: () => _showAboutDialog(context, theme, cs),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildLogoutButton(ThemeData theme, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(context, theme, cs),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.danger.withValues(alpha: isDark ? 0.18 : 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Log Out',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ThemeData theme, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleLogout(context);
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await _authService.signOut();
      updateProfile(null);
      themeNotifier.value = ThemeMode.dark;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        updateProfile(null);
        themeNotifier.value = ThemeMode.dark;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        context.go('/login');
      }
    }
  }

  void _showHelpDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(
              icon: Icons.email_outlined,
              title: 'Email Us',
              subtitle: 'support@guardiancircle.com',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
            _HelpItem(
              icon: Icons.chat_outlined,
              title: 'Live Chat',
              subtitle: 'Available 24/7',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
            _HelpItem(
              icon: Icons.article_outlined,
              title: 'FAQ',
              subtitle: 'Common questions',
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    showAboutDialog(
      context: context,
      applicationName: 'GuardianCircle',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('Family safety and location sharing app.'),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Confirm new password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
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
                const SnackBar(content: Text('Password updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your privacy matters to us.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'GuardianCircle collects location data to enable family safety features. '
                'Location data is only shared with family members in your circle.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We do not sell your data to third parties. '
                'You can pause location sharing at any time in Settings.',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'For full details, visit guardiancircle.com/privacy',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.45),
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

class _GlassSection extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _GlassSection({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.75),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: cs.outline.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.18),
              ),
          ],
        ),
      ),
    );
  }
}
