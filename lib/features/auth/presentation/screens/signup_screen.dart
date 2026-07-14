import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/app/auth_service.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService.defaultClient();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await _authService.signUp(_emailController.text, _passwordController.text);
      if (!mounted) return;
      if (user.emailConfirmedAt != null) {
        context.go('/home');
      } else {
        _showSuccess('Account created! Please check your email.');
        Future.delayed(const Duration(seconds: 2), () { if (mounted) context.go('/login'); });
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 32),
                    Text('Create account', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                    const SizedBox(height: 8),
                    Text('Join your family\'s circle', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 48),
                    _buildInput(controller: _emailController, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
                    const SizedBox(height: 16),
                    _buildInput(controller: _passwordController, label: 'Password', icon: Icons.lock_outline_rounded, obscure: _obscurePassword, textInputAction: TextInputAction.next,
                      suffix: GestureDetector(onTap: () => setState(() => _obscurePassword = !_obscurePassword), child: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: cs.onSurface.withValues(alpha: 0.4), size: 22))),
                    const SizedBox(height: 16),
                    _buildInput(controller: _confirmPasswordController, label: 'Confirm Password', icon: Icons.lock_outline_rounded, obscure: _obscureConfirmPassword, textInputAction: TextInputAction.done,
                      suffix: GestureDetector(onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), child: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: cs.onSurface.withValues(alpha: 0.4), size: 22)),
                      onSubmitted: (_) => _handleSignup()),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _loading ? null : _handleSignup,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [cs.primary, cs.tertiary.withValues(alpha: 0.85)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 15)),
                        GestureDetector(
                          onTap: _loading ? null : () => context.go('/login'),
                          child: const Text('Sign In', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        enabled: !_loading,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: cs.onSurface.withValues(alpha: 0.35), size: 22),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return '$label is required.';
          if (label == 'Email' && (!value.contains('@') || !value.contains('.'))) return 'Enter a valid email.';
          if (label == 'Confirm Password' && value != _passwordController.text) return 'Passwords do not match.';
          if (label == 'Password' && value.length < 6) return 'At least 6 characters.';
          return null;
        },
      ),
    );
  }
}
