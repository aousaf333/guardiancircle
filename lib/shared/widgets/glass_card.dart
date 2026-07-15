import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final double? height;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool animate;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppTheme.cardRadius,
    this.blurSigma = 20,
    this.height,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.animate = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(GlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final bgColor = widget.backgroundColor ??
        (ext?.glassBackground ??
            (isDark ? const Color(0xFF111827) : Colors.white));
    final bdrColor = widget.borderColor ??
        (ext?.glassBorder ?? cs.outline.withValues(alpha: 0.3));

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: widget.blurSigma,
          sigmaY: widget.blurSigma,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          transform: Matrix4.diagonal3Values(
              _isPressed ? 0.985 : 1.0, _isPressed ? 0.985 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: bdrColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: (ext?.cardShadow ??
                        Colors.black.withValues(alpha: isDark ? 0.35 : 0.03))
                    .withValues(alpha: _isPressed ? 0.15 : 1.0),
                blurRadius: _isPressed ? 12 : 24,
                offset: Offset(0, _isPressed ? 2 : 8),
              ),
            ],
          ),
          padding: widget.padding ?? const EdgeInsets.all(20),
          child: widget.child,
        ),
      ),
    );

    Widget result = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _fadeAnim.value,
        child: Transform.translate(
          offset: _slideAnim.value,
          child: Transform.scale(scale: _scaleAnim.value, child: child),
        ),
      ),
      child: card,
    );

    if (widget.onTap != null) {
      result = GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: result,
      );
    }

    return Container(
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      height: widget.height,
      child: result,
    );
  }
}
