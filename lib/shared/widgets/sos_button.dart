import 'package:flutter/material.dart';

class SosButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const SosButton({super.key, this.onPressed});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _pressController;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _pressScaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _pressScaleAnim = Tween<double>(begin: 1, end: 0.92).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const sosRed = Color(0xFFEF4444);

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) { _pressController.reverse(); widget.onPressed?.call(); },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _pressScaleAnim,
        builder: (context, child) => Transform.scale(scale: _pressScaleAnim.value, child: child),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) => Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [sosRed, sosRed.withValues(alpha: 0.8)] : [sosRed, const Color(0xFFFF453A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: sosRed.withValues(alpha: _pulseAnim.value * (isDark ? 0.4 : 0.3)),
                  blurRadius: 24 + (_pulseAnim.value * 8),
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3 + _pulseAnim.value * 0.2), width: 2)),
                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('SOS EMERGENCY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Press to alert your circle', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ]),
              const Spacer(),
              Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22)),
            ],
          ),
        ),
      ),
    );
  }
}
