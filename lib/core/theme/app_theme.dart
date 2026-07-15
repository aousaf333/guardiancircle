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
  final Color surfaceElevated;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppThemeExtension({
    required this.glassBackground,
    required this.glassBorder,
    required this.backgroundGradient,
    required this.mapOverlayBackground,
    required this.blurSigma,
    required this.activePulseColor,
    required this.cardShadow,
    required this.primaryGlow,
    this.surfaceElevated = const Color(0xFF1E293B),
    this.shimmerBase = const Color(0xFF1E293B),
    this.shimmerHighlight = const Color(0xFF334155),
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
    Color? surfaceElevated,
    Color? shimmerBase,
    Color? shimmerHighlight,
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
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
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
        (index) => Color.lerp(
          backgroundGradient[index],
          other.backgroundGradient[index],
          t,
        )!,
      ),
      mapOverlayBackground:
          Color.lerp(mapOverlayBackground, other.mapOverlayBackground, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t),
      activePulseColor:
          Color.lerp(activePulseColor, other.activePulseColor, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      primaryGlow: Color.lerp(primaryGlow, other.primaryGlow, t)!,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }

  static double lerpDouble(double? a, double? b, double t) {
    return a! + (b! - a) * t;
  }
}

class AppTheme {
  AppTheme._();

  // ── Premium 2026 Color Palette ──
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentLight = Color(0xFF22D3EE);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFF87171);
  static const Color tertiary = Color(0xFF8B5CF6);
  static const Color tertiaryLight = Color(0xFFA78BFA);

  // ── Dark Theme Colors ──
  static const Color _darkBg = Color(0xFF0A0F1E);
  static const Color _darkBgGradient = Color(0xFF060A14);
  static const Color _darkSurface = Color(0xFF111827);
  static const Color _darkSurfaceLight = Color(0xFF1F2937);
  static const Color _darkSurfaceElevated = Color(0xFF1A2332);
  static const Color _darkOnSurface = Color(0xFFF1F5F9);
  static const Color _darkOnSurfaceMedium = Color(0xFF94A3B8);

  // ── Light Theme Colors ──
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _lightBgGradient = Color(0xFFEFF6FF);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color _lightOnSurface = Color(0xFF0F172A);
  static const Color _lightOnSurfaceMedium = Color(0xFF64748B);

  // ── Design Tokens ──
  static const double cardRadius = 22.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 16.0;
  static const double chipRadius = 100.0;
  static const double sectionRadius = 20.0;

  // ── Premium Typography ──
  static TextTheme _buildTextTheme(Color base, Color medium) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.1,
        color: base,
      ),
      displayMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        color: base,
      ),
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.2,
        color: base,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: base,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
        color: base,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
        color: base,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
        color: base,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.35,
        color: base,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        height: 1.35,
        color: base,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        height: 1.5,
        color: base,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        height: 1.45,
        color: base,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.4,
        color: medium,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: base,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: medium,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: medium,
      ),
    );
  }

  static final ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: primaryDark,
    onPrimaryContainer: Colors.white,
    secondary: accent,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF0E7490),
    onSecondaryContainer: Colors.white,
    tertiary: tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFF6D28D9),
    onTertiaryContainer: Colors.white,
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    onSurfaceVariant: _darkOnSurfaceMedium,
    surfaceContainer: _darkSurfaceLight,
    surfaceContainerLow: _darkSurfaceElevated,
    error: danger,
    onError: Colors.white,
    outline: Colors.white.withValues(alpha: 0.08),
    outlineVariant: Colors.white.withValues(alpha: 0.04),
  );

  static final ColorScheme _lightColorScheme = ColorScheme.light(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDBEAFE),
    onPrimaryContainer: primaryDark,
    secondary: accent,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFCFFAFE),
    onSecondaryContainer: const Color(0xFF0E7490),
    tertiary: const Color(0xFF7C3AED),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFEDE9FE),
    onTertiaryContainer: const Color(0xFF5B21B6),
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    onSurfaceVariant: _lightOnSurfaceMedium,
    surfaceContainer: _lightSurfaceElevated,
    surfaceContainerLow: const Color(0xFFE2E8F0),
    error: danger,
    onError: Colors.white,
    outline: Colors.black.withValues(alpha: 0.08),
    outlineVariant: Colors.black.withValues(alpha: 0.04),
  );

  // ── Light Theme ──
  static ThemeData get lightTheme {
    final cs = _lightColorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: _lightBg,
      textTheme: _buildTextTheme(_lightOnSurface, _lightOnSurfaceMedium),
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
        titleTextStyle: TextStyle(
          color: _lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: _lightOnSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w500,
        ),
        hintStyle:
            TextStyle(color: _lightOnSurface.withValues(alpha: 0.3)),
        prefixIconColor:
            _lightOnSurface.withValues(alpha: 0.35),
        suffixIconColor:
            _lightOnSurface.withValues(alpha: 0.35),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(58),
          side: BorderSide(
            color: primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _lightOnSurface,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.05),
        thickness: 0.5,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : cs.surfaceContainer,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: _lightSurface,
        elevation: 20,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          glassBackground: Colors.white.withValues(alpha: 0.75),
          glassBorder: Colors.white.withValues(alpha: 0.5),
          backgroundGradient: const [_lightBg, _lightBgGradient],
          mapOverlayBackground: Colors.white.withValues(alpha: 0.92),
          blurSigma: 20.0,
          activePulseColor: primary.withValues(alpha: 0.1),
          cardShadow: Colors.black.withValues(alpha: 0.03),
          primaryGlow: primary.withValues(alpha: 0.12),
          surfaceElevated: _lightSurfaceElevated,
          shimmerBase: const Color(0xFFE2E8F0),
          shimmerHighlight: const Color(0xFFF1F5F9),
        ),
      ],
    );
  }

  // ── Dark Theme ──
  static ThemeData get darkTheme {
    final cs = _darkColorScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: _darkBg,
      textTheme: _buildTextTheme(_darkOnSurface, _darkOnSurfaceMedium),
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
        titleTextStyle: const TextStyle(
          color: _darkOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceLight.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: _darkOnSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w500,
        ),
        hintStyle:
            TextStyle(color: _darkOnSurface.withValues(alpha: 0.25)),
        prefixIconColor:
            _darkOnSurface.withValues(alpha: 0.35),
        suffixIconColor:
            _darkOnSurface.withValues(alpha: 0.35),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(58),
          side: BorderSide(
            color: primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _darkSurfaceLight,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        thickness: 0.5,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : _darkSurfaceLight,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: _darkSurface,
        elevation: 20,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          glassBackground: _darkSurface.withValues(alpha: 0.55),
          glassBorder: Colors.white.withValues(alpha: 0.07),
          backgroundGradient: const [_darkBg, _darkBgGradient],
          mapOverlayBackground: _darkBg.withValues(alpha: 0.88),
          blurSigma: 24.0,
          activePulseColor: primary.withValues(alpha: 0.15),
          cardShadow: Colors.black.withValues(alpha: 0.35),
          primaryGlow: primary.withValues(alpha: 0.18),
          surfaceElevated: _darkSurfaceElevated,
          shimmerBase: _darkSurfaceLight,
          shimmerHighlight: _darkSurfaceElevated,
        ),
      ],
    );
  }
}
