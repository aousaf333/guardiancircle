import 'package:flutter/material.dart';

class PremiumInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final String? Function(String?)? validator;

  const PremiumInput({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
    this.enabled = true,
    this.validator,
  });

  @override
  State<PremiumInput> createState() => _PremiumInputState();
}

class _PremiumInputState extends State<PremiumInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: _isFocused ? 0.06 : 0.04)
            : Colors.black.withValues(alpha: _isFocused ? 0.04 : 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused
              ? cs.primary.withValues(alpha: 0.5)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08)),
          width: _isFocused ? 1.5 : 0.5,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        enabled: widget.enabled,
        onFieldSubmitted: widget.onSubmitted,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _isFocused
                ? cs.primary.withValues(alpha: 0.8)
                : cs.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              widget.icon,
              color: _isFocused
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.35),
              size: 22,
            ),
          ),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: widget.validator ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return '${widget.label} is required.';
              }
              return null;
            },
      ),
    );
  }
}
