import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardiancircle/app/auth_service.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService.defaultClient();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
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
    _fadeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _authService.signIn(_emailController.text, _passwordController.text);
      if (mounted) context.go('/home');
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
                    // Logo
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 32),
                    Text('Welcome back', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                    const SizedBox(height: 8),
                    Text('Sign in to your GuardianCircle', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 48),
                    // Email
                    _buildInput(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // Password
                    _buildInput(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: cs.onSurface.withValues(alpha: 0.4), size: 22),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _loading ? null : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset coming soon'))),
                        child: Text('Forgot Password?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Login button
                    GestureDetector(
                      onTap: _loading ? null : _handleLogin,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.8)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Divider
                    Row(children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('or', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.3), fontSize: 13))),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.08))),
                    ]),
                    const SizedBox(height: 24),
                    // Social buttons
                    _buildSocialButton('Continue with Google', Icons.g_mobiledata_rounded, const Color(0xFFEA4335)),
                    const SizedBox(height: 12),
                    _buildSocialButton('Continue with Apple', Icons.apple_rounded, Colors.white),
                    const SizedBox(height: 40),
                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 15)),
                        GestureDetector(
                          onTap: _loading ? null : () => context.push('/signup'),
                          child: const Text('Sign Up', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15)),
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
          return null;
        },
      ),
    );
  }

  Widget _buildSocialButton(String text, IconData icon, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
