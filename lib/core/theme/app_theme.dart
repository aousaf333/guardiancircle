import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color glassBackground;
  final Color glassBorder;
  final List<Color> backgroundGradient;
  final Color mapOverlayBackground;
  final double blurSigma;
  final Color activePulseColor;
  final Color cardShadow;
  final Color primaryGlow;

  const AppThemeExtension({
    required this.glassBackground,
    required this.glassBorder,
    required this.backgroundGradient,
    required this.mapOverlayBackground,
    required this.blurSigma,
    required this.activePulseColor,
    required this.cardShadow,
    required this.primaryGlow,
  });

  @override
  AppThemeExtension copyWith({
    Color? glassBackground,
    Color? glassBorder,
    List<Color>? backgroundGradient,
    Color? mapOverlayBackground,
    double? blurSigma,
    Color? activePulseColor,
    Color? cardShadow,
    Color? primaryGlow,
  }) {
    return AppThemeExtension(
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      mapOverlayBackground: mapOverlayBackground ?? this.mapOverlayBackground,
      blurSigma: blurSigma ?? this.blurSigma,
      activePulseColor: activePulseColor ?? this.activePulseColor,
      cardShadow: cardShadow ?? this.cardShadow,
      primaryGlow: primaryGlow ?? this.primaryGlow,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      backgroundGradient: List<Color>.generate(
        backgroundGradient.length,
        (index) => Color.lerp(backgroundGradient[index], other.backgroundGradient[index], t)!,
      ),
      mapOverlayBackground: Color.lerp(mapOverlayBackground, other.mapOverlayBackground, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t),
      activePulseColor: Color.lerp(activePulseColor, other.activePulseColor, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
    );
  }

  static double lerpDouble(double? a, double? b, double t) {
    return a! + (b! - a) * t;
  }
}

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2563EB);
  static const Color accent = Color(0xFF06B6D4);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkSurface = Color(0xFF1E293B);
  static const Color _darkSurfaceLight = Color(0xFF334155);
  static const Color _darkOnSurface = Color(0xFFF1F5F9);

  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightOnSurface = Color(0xFF0F172A);

  static const double cardRadius = 20.0;
  static const double buttonRadius = 14.0;
  static const double inputRadius = 14.0;
  static const double chipRadius = 100.0;

  static TextTheme _buildTextTheme(Color base) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15, color: base),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.2, color: base),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.25, color: base),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: base),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.3, color: base),
      headlineSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3, color: base),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3, color: base),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.35, color: base),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.35, color: base),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.1, height: 1.5, color: base),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.1, height: 1.45, color: base),
      bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.4, color: base.withValues(alpha: 0.6)),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: base),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0, color: base),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: base.withValues(alpha: 0.5)),
    );
  }

  static final ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.white,
    secondary: accent,
    onSecondary: Colors.white,
    tertiary: const Color(0xFF8B5CF6),
    onTertiary: Colors.white,
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    surfaceContainer: _darkSurfaceLight,
    error: danger,
    onError: Colors.white,
  );

  static final ColorScheme _lightColorScheme = ColorScheme.light(
    primary: primary,
    onPrimary: Colors.white,
    secondary: accent,
    onSecondary: Colors.white,
    tertiary: const Color(0xFF7C3AED),
    onTertiary: Colors.white,
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    surfaceContainer: const Color(0xFFE2E8F0),
    error: danger,
    onError: Colors.white,
  );

  static ThemeData get lightTheme {
    final cs = _lightColorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: _lightBg,
      textTheme: _buildTextTheme(_lightOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _lightOnSurface, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(color: _lightOnSurface, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: const BorderSide(color: danger, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: const BorderSide(color: danger, width: 1.5)),
        labelStyle: TextStyle(color: _lightOnSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: _lightOnSurface.withValues(alpha: 0.35)),
        prefixIconColor: _lightOnSurface.withValues(alpha: 0.4),
        suffixIconColor: _lightOnSurface.withValues(alpha: 0.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: primary.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _lightOnSurface,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: Colors.black.withValues(alpha: 0.06), thickness: 0.5, space: 0),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : cs.surfaceContainer),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          glassBackground: Colors.white.withValues(alpha: 0.7),
          glassBorder: Colors.white.withValues(alpha: 0.4),
          backgroundGradient: const [_lightBg, Color(0xFFE2E8F0)],
          mapOverlayBackground: Colors.white.withValues(alpha: 0.9),
          blurSigma: 20.0,
          activePulseColor: primary.withValues(alpha: 0.12),
          cardShadow: Colors.black.withValues(alpha: 0.04),
          primaryGlow: primary.withValues(alpha: 0.15),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    final cs = _darkColorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: _darkBg,
      textTheme: _buildTextTheme(_darkOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _darkOnSurface, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(color: _darkOnSurface, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceLight.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: const BorderSide(color: danger, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(inputRadius), borderSide: const BorderSide(color: danger, width: 1.5)),
        labelStyle: TextStyle(color: _darkOnSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: _darkOnSurface.withValues(alpha: 0.3)),
        prefixIconColor: _darkOnSurface.withValues(alpha: 0.4),
        suffixIconColor: _darkOnSurface.withValues(alpha: 0.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: primary.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _darkSurfaceLight,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.06), thickness: 0.5, space: 0),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : _darkSurfaceLight),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          glassBackground: _darkSurface.withValues(alpha: 0.6),
          glassBorder: Colors.white.withValues(alpha: 0.08),
          backgroundGradient: const [_darkBg, Color(0xFF0B1120)],
          mapOverlayBackground: _darkBg.withValues(alpha: 0.85),
          blurSigma: 24.0,
          activePulseColor: primary.withValues(alpha: 0.18),
          cardShadow: Colors.black.withValues(alpha: 0.3),
          primaryGlow: primary.withValues(alpha: 0.2),
        ),
      ],
    );
  }
}
