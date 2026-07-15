import 'package:guardiancircle/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _supabaseClient;

  /// When SUPABASE_URL is not provided, the app runs in placeholder mode
  /// and accepts any non-empty credentials without calling Supabase.
  static bool get _isPlaceholder => SupabaseService.isPlaceholder;

  AuthService(this._supabaseClient);

  factory AuthService.defaultClient() =>
      AuthService(Supabase.instance.client);

  User? get currentUser => _supabaseClient.auth.currentUser;

  Session? get currentSession => _supabaseClient.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _supabaseClient.auth.onAuthStateChange;

  Future<User> signUp(String email, String password) async {
    if (email.trim().isEmpty) {
      throw const AuthException('Email is required.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }

    try {
      print('[SIGNUP] Attempting signUp for: ${email.trim()}');

      final response = await _supabaseClient.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw const AuthException('Sign up failed. Please try again.');
      }

      print('[SIGNUP] Success for: ${email.trim()} — userId: ${response.user!.id}');
      return response.user!;
    } on AuthException {
      rethrow;
    } catch (e) {
      final ex = e as dynamic;
      print('[SIGNUP] ─── ERROR ───');
      print('[SIGNUP] email:        ${email.trim()}');
      print('[SIGNUP] message:      ${ex.message ?? e.toString()}');
      print('[SIGNUP] statusCode:   ${ex.statusCode ?? "N/A"}');
      print('[SIGNUP] errorCode:    ${ex.errorCode ?? "N/A"}');
      print('[SIGNUP] fullException: $e');
      print('[SIGNUP] ─────────────');
      throw AuthException(_mapAuthError(e.toString()));
    }
  }

  Future<User?> signIn(String email, String password) async {
    if (email.trim().isEmpty) {
      throw const AuthException('Email is required.');
    }
    if (password.isEmpty) {
      throw const AuthException('Password is required.');
    }

    // Placeholder mode: accept any valid credentials without Supabase.
    if (_isPlaceholder) return null;

    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw const AuthException('Login failed. Please try again.');
      }

      return response.user!;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(_mapAuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
    } catch (e) {
      throw AuthException(_mapAuthError(e.toString()));
    }
  }

  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty) {
      throw const AuthException('Email is required.');
    }

    try {
      await _supabaseClient.auth.resetPasswordForEmail(email.trim());
    } catch (e) {
      throw AuthException(_mapAuthError(e.toString()));
    }
  }

  String _mapAuthError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('unable to validate email address')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'An error occurred. Please try again.';
  }
}
