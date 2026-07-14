import 'dart:async';
import 'package:flutter/material.dart';
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
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _sosPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
    _activateSos();
  }

  @override
  void dispose() { _countdownTimer?.cancel(); _fadeController.dispose(); _sosPulseController.dispose(); super.dispose(); }

  void _activateSos() {
    setState(() { _sosActive = true; _countdown = 10; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() { _sosActive = false; _countdown = 0; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency contacts have been notified')));
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelSos() {
    _countdownTimer?.cancel();
    setState(() { _sosActive = false; _countdown = 0; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS alert cancelled')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: _sosActive ? [const Color(0xFF1A0505), const Color(0xFF0F172A)] : [const Color(0xFF0F172A), const Color(0xFF0B1120)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                const SizedBox(height: 12),
                Row(children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5)), child: Icon(Icons.chevron_left_rounded, color: cs.onSurface, size: 24))),
                  const SizedBox(width: 12),
                  Text('SOS', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ]),
                const SizedBox(height: 20),
                // SOS Button
                _buildSosButton(cs, isDark),
                const SizedBox(height: 20),
                if (_sosActive) ...[
                  Text('Alerting in $_countdown seconds', style: TextStyle(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 20),
                  // Cancel button
                  GestureDetector(
                    onTap: _cancelSos,
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5)),
                      child: Center(child: Text('Cancel SOS', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 16))),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Quick actions
                SectionHeader(title: 'Quick Actions'),
                _buildQuickActions(cs, isDark),
                const SizedBox(height: 16),
                // Emergency contacts
                SectionHeader(title: 'Emergency Contacts'),
                _buildEmergencyContacts(cs, isDark),
                const SizedBox(height: 16),
                // Tips
                SectionHeader(title: 'Safety Tips'),
                _buildSafetyTips(cs, isDark),
                const SizedBox(height: 100),
              ]),
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
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFFEF4444), _sosActive ? const Color(0xFF991B1B) : const Color(0xFFDC2626)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: (_sosActive ? 0.5 : 0.3) + _sosPulseController.value * 0.15), blurRadius: 40 + _sosPulseController.value * 10, spreadRadius: _sosActive ? 4 : 0)],
        ),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
            child: Icon(_sosActive ? Icons.emergency_rounded : Icons.warning_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 12),
          Text(_sosActive ? 'EMERGENCY ACTIVE' : 'SOS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(_sosActive ? 'All members are being alerted' : 'Press to activate emergency alert', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildQuickActions(ColorScheme cs, bool isDark) {
    final actions = [
      _SosAction(icon: Icons.share_location_rounded, label: 'Share Location', color: cs.primary),
      _SosAction(icon: Icons.mic_rounded, label: 'Audio', color: const Color(0xFF8B5CF6)),
      _SosAction(icon: Icons.camera_alt_rounded, label: 'Photo', color: const Color(0xFFEC4899)),
      _SosAction(icon: Icons.flashlight_on_rounded, label: 'Flashlight', color: const Color(0xFFF59E0B)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: actions.map((a) => Expanded(child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${a.label} activated'))),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: a.color.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(a.icon, color: a.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(a.label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
        ]),
      ))).toList()),
    );
  }

  Widget _buildEmergencyContacts(ColorScheme cs, bool isDark) {
    final contacts = [
      _Contact(name: 'Sarah Miller', relation: 'Mom', color: const Color(0xFFEC4899)),
      _Contact(name: 'James Miller', relation: 'Dad', color: const Color(0xFF3B82F6)),
    ];

    return Column(children: contacts.map((c) => GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling ${c.name}...'))),
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [c.color, c.color.withValues(alpha: 0.65)]), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(c.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface, fontSize: 15)), Text(c.relation, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13))])),
          Icon(Icons.phone_rounded, color: const Color(0xFF10B981), size: 22),
        ]),
      ),
    )).toList());
  }

  Widget _buildSafetyTips(ColorScheme cs, bool isDark) {
    final tips = [
      _Tip(icon: Icons.location_on_rounded, title: 'Stay visible', subtitle: 'Keep location sharing enabled', color: cs.primary),
      _Tip(icon: Icons.battery_full_rounded, title: 'Keep charged', subtitle: 'Maintain at least 20% battery', color: const Color(0xFFF59E0B)),
      _Tip(icon: Icons.people_rounded, title: 'Stay connected', subtitle: 'Check in with your circle daily', color: const Color(0xFF10B981)),
    ];

    return Column(children: tips.map((t) => Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface.withValues(alpha: isDark ? 0.5 : 0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(t.icon, color: t.color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface, fontSize: 14)), Text(t.subtitle, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 13))])),
      ]),
    )).toList());
  }
}

class _SosAction { final IconData icon; final String label; final Color color; const _SosAction({required this.icon, required this.label, required this.color}); }
class _Contact { final String name; final String relation; final Color color; const _Contact({required this.name, required this.relation, required this.color}); }
class _Tip { final IconData icon; final String title; final String subtitle; final Color color; const _Tip({required this.icon, required this.title, required this.subtitle, required this.color}); }
