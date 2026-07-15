import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/shared/widgets/glass_card.dart';
import 'package:guardiancircle/shared/widgets/section_header.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  bool _sosActive = false;
  int _countdown = 10;
  Timer? _countdownTimer;
  late final AnimationController _fadeController;
  late final AnimationController _sosPulseController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _activateSos();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fadeController.dispose();
    _sosPulseController.dispose();
    super.dispose();
  }

  void _activateSos() {
    setState(() {
      _sosActive = true;
      _countdown = 10;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() {
          _sosActive = false;
          _countdown = 0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Emergency contacts have been notified')),
          );
        }
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelSos() {
    _countdownTimer?.cancel();
    setState(() {
      _sosActive = false;
      _countdown = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS alert cancelled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _sosActive
                ? [const Color(0xFF1A0505), const Color(0xFF0A0F1E)]
                : ext?.backgroundGradient ??
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: cs.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SOS',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSosButton(cs, isDark),
                  const SizedBox(height: 20),
                  if (_sosActive) ...[
                    Text(
                      'Alerting in $_countdown seconds',
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _cancelSos,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel SOS',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'Quick Actions'),
                  _buildQuickActions(cs, isDark),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Emergency Contacts'),
                  _buildEmergencyContacts(cs, isDark),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Safety Tips'),
                  _buildSafetyTips(cs, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSosButton(ColorScheme cs, bool isDark) {
    return AnimatedBuilder(
      animation: _sosPulseController,
      builder: (context, child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.danger,
              _sosActive ? const Color(0xFF991B1B) : const Color(0xFFDC2626),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppTheme.danger.withValues(
                alpha: (_sosActive ? 0.5 : 0.3) +
                    _sosPulseController.value * 0.15,
              ),
              blurRadius: 44 + _sosPulseController.value * 10,
              spreadRadius: _sosActive ? 4 : 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _sosActive ? Icons.emergency_rounded : Icons.warning_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _sosActive ? 'EMERGENCY ACTIVE' : 'SOS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _sosActive
                  ? 'All members are being alerted'
                  : 'Press to activate emergency alert',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme cs, bool isDark) {
    final actions = [
      _SosAction(
        icon: Icons.share_location_rounded,
        label: 'Share Location',
        color: cs.primary,
      ),
      _SosAction(
        icon: Icons.mic_rounded,
        label: 'Audio',
        color: AppTheme.tertiary,
      ),
      _SosAction(
        icon: Icons.camera_alt_rounded,
        label: 'Photo',
        color: const Color(0xFFEC4899),
      ),
      _SosAction(
        icon: Icons.flashlight_on_rounded,
        label: 'Flashlight',
        color: AppTheme.warning,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: actions
            .map(
              (a) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${a.label} activated'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(a.icon, color: a.color, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildEmergencyContacts(ColorScheme cs, bool isDark) {
    final contacts = [
      _Contact(
        name: 'Sarah Miller',
        relation: 'Mom',
        color: const Color(0xFFEC4899),
      ),
      _Contact(
        name: 'James Miller',
        relation: 'Dad',
        color: const Color(0xFF3B82F6),
      ),
    ];

    return Column(
      children: contacts
          .map(
            (c) => GlassCard(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.color,
                          c.color.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        c.name.characters.first,
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
                          c.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          c.relation,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.35),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.phone_rounded,
                    color: AppTheme.success,
                    size: 22,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSafetyTips(ColorScheme cs, bool isDark) {
    final tips = [
      _Tip(
        icon: Icons.location_on_rounded,
        title: 'Stay visible',
        subtitle: 'Keep location sharing enabled',
        color: cs.primary,
      ),
      _Tip(
        icon: Icons.battery_full_rounded,
        title: 'Keep charged',
        subtitle: 'Maintain at least 20% battery',
        color: AppTheme.warning,
      ),
      _Tip(
        icon: Icons.people_rounded,
        title: 'Stay connected',
        subtitle: 'Check in with your circle daily',
        color: AppTheme.success,
      ),
    ];

    return Column(
      children: tips
          .map(
            (t) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.45 : 0.65),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(t.icon, color: t.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          t.subtitle,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SosAction {
  final IconData icon;
  final String label;
  final Color color;
  const _SosAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _Contact {
  final String name;
  final String relation;
  final Color color;
  const _Contact({
    required this.name,
    required this.relation,
    required this.color,
  });
}

class _Tip {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Tip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
