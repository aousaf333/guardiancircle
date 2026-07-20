import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/services/emergency_alert_service.dart';
import 'package:guardiancircle/shared/widgets/section_header.dart';
import 'package:geolocator/geolocator.dart';

class SosScreen extends StatefulWidget {
  final String? existingAlertId;
  const SosScreen({super.key, this.existingAlertId});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  final EmergencyAlertService _service = EmergencyAlertService.defaultClient();
  bool _sosActive = false;
  bool _isLoading = false;
  String? _activeAlertId;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
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

    if (widget.existingAlertId != null) {
      _activeAlertId = widget.existingAlertId;
      _sosActive = true;
      _startElapsedTimer();
      _service.startLocationUpdates(widget.existingAlertId!);
    } else {
      _activateSos();
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _fadeController.dispose();
    _sosPulseController.dispose();
    _service.stopLocationUpdates();
    super.dispose();
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String get _elapsedText {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _activateSos() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission required')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      print('[SOS] Current position: ${position.latitude}, ${position.longitude}');

      final alert = await _service.createSosAlert(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (alert != null && mounted) {
        print('[SOS] SOS Created: alertId=${alert.id}');
        setState(() {
          _sosActive = true;
          _isLoading = false;
          _activeAlertId = alert.id;
        });
        _startElapsedTimer();
        _service.startLocationUpdates(alert.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Alert sent to all family members')),
        );
      }
    } catch (e) {
      print('[SOS] _activateSos: ERROR=$e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    }
  }

  Future<void> _cancelSos() async {
    if (_activeAlertId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel SOS Alert?'),
        content: const Text(
          'This will cancel the emergency alert. Family members will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Active'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.cancelSosAlert(_activeAlertId!);
      print('[SOS] SOS Cancelled: alertId=$_activeAlertId');
      _service.stopLocationUpdates();
      _elapsedTimer?.cancel();
      setState(() {
        _sosActive = false;
        _activeAlertId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS alert cancelled')),
        );
      }
    } catch (e) {
      print('[SOS] _cancelSos: ERROR=$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    }
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
                        onTap: () {
                          if (_sosActive) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'SOS is still active. Cancel it before leaving.',
                                ),
                              ),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
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
                      if (_sosActive) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.danger,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x80EF4444),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSosButton(cs, isDark),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  else if (_sosActive) ...[
                    Text(
                      'Emergency Active',
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elapsed: $_elapsedText',
                      style: TextStyle(
                        color: AppTheme.dangerLight.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All family members are being alerted',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
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
                  if (!_sosActive) ...[
                    const SectionHeader(title: 'Safety Tips'),
                    _buildSafetyTips(cs, isDark),
                  ],
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
                  ? 'Help is on the way'
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
