import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom theme extension to provide premium design system colors and gradients
/// inspired by Apple Find My, Life360, and modern glassmorphism.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color glassBackground;
  final Color glassBorder;
  final List<Color> backgroundGradient;
  final Color mapOverlayBackground;
  final double blurSigma;
  final Color activePulseColor;

  const AppThemeExtension({
    required this.glassBackground,
    required this.glassBorder,
    required this.backgroundGradient,
    required this.mapOverlayBackground,
    required this.blurSigma,
    required this.activePulseColor,
  });

  @override
  AppThemeExtension copyWith({
    Color? glassBackground,
    Color? glassBorder,
    List<Color>? backgroundGradient,
    Color? mapOverlayBackground,
    double? blurSigma,
    Color? activePulseColor,
  }) {
    return AppThemeExtension(
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      mapOverlayBackground: mapOverlayBackground ?? this.mapOverlayBackground,
      blurSigma: blurSigma ?? this.blurSigma,
      activePulseColor: activePulseColor ?? this.activePulseColor,
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
    );
  }

  // Helper double interpolation for lerp
  static double lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Dynamic, ultra-premium theme configuration for GuardianCircle.
/// Designed with Material 3, custom modern typography, rounded buttons, and premium dark/light color schemes.
class AppTheme {
  AppTheme._();

  // Premium Design System Colors
  static const Color _lightPrimary = Color(0xFF0066FF); // Premium Electric Blue
  static const Color _lightSecondary = Color(0xFF10B981); // Emerald Active Green
  static const Color _lightTertiary = Color(0xFF8B5CF6); // Modern Royal Purple
  static const Color _lightBackground = Color(0xFFF8FAFC); // Very light cool grey slate
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightOnSurface = Color(0xFF0F172A); // Midnight dark text

  static const Color _darkPrimary = Color(0xFF3B82F6); // Soft Vibrant Blue for Dark Mode
  static const Color _darkSecondary = Color(0xFF34D399); // Soft Emerald Green
  static const Color _darkTertiary = Color(0xFFA78BFA); // Soft Royal Purple
  static const Color _darkBackground = Color(0xFF0B0F19); // Deep dark space/navy blue
  static const Color _darkSurface = Color(0xFF151D30); // Premium dark navy card surface
  static const Color _darkOnSurface = Color(0xFFF8FAFC); // Light cool slate text

  // Common Corner Radii
  static const double cardRadius = 24.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 14.0;

  /// Modern typography setup utilizing default system sans-serif fonts with precise spacing and weight.
  static TextTheme _buildTextTheme(Color baseTextColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: baseTextColor,
      ),
      displayMedium: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: baseTextColor,
      ),
      displaySmall: TextStyle(
        fontSize: 24.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: baseTextColor,
      ),
      headlineLarge: TextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: baseTextColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 20.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: baseTextColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
        color: baseTextColor,
      ),
      titleLarge: TextStyle(
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: baseTextColor,
      ),
      titleMedium: TextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: baseTextColor,
      ),
      titleSmall: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: baseTextColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        height: 1.4,
        color: baseTextColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        height: 1.4,
        color: baseTextColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        color: baseTextColor.withOpacity(0.7),
      ),
      labelLarge: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: baseTextColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: baseTextColor,
      ),
      labelSmall: TextStyle(
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: baseTextColor.withOpacity(0.6),
      ),
    );
  }

  /// Premium Light Theme Specification
  static ThemeData get lightTheme {
    final ColorScheme colorScheme = const ColorScheme.light(
      primary: _lightPrimary,
      secondary: _lightSecondary,
      tertiary: _lightTertiary,
      background: _lightBackground,
      surface: _lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onBackground: _lightOnSurface,
      onSurface: _lightOnSurface,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: _buildTextTheme(_lightOnSurface),
      
      // Status bar style configuration
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _lightOnSurface, size: 24),
        actionsIconTheme: IconThemeData(color: _lightOnSurface, size: 24),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: _lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // Premium rounded cards with very light shadow
      cardTheme: CardTheme(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: Colors.black.withOpacity(0.04),
            width: 1.0,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Beautiful inputs with modern states
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: _lightPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        labelStyle: TextStyle(color: _lightOnSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: _lightOnSurface.withOpacity(0.4)),
        prefixIconColor: _lightOnSurface.withOpacity(0.5),
        suffixIconColor: _lightOnSurface.withOpacity(0.5),
      ),

      // Elegant Button Styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) return Colors.white.withOpacity(0.12);
              return null;
            },
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: _lightPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Modern Tab Bar
      tabBarTheme: TabBarTheme(
        labelColor: _lightPrimary,
        unselectedLabelColor: _lightOnSurface.withOpacity(0.5),
        indicatorColor: _lightPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // Minimal Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _lightPrimary.withOpacity(0.1),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: _lightPrimary);
          }
          return IconThemeData(color: _lightOnSurface.withOpacity(0.5));
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: _lightPrimary, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: _lightOnSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500);
        }),
        elevation: 8,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _lightPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Custom extensions for Find My-style overlays
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          glassBackground: Colors.white.withOpacity(0.75),
          glassBorder: Colors.white.withOpacity(0.4),
          backgroundGradient: const [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
          ],
          mapOverlayBackground: Colors.white.withOpacity(0.9),
          blurSigma: 15.0,
          activePulseColor: _lightPrimary.withOpacity(0.2),
        ),
      ],
    );
  }

  /// Premium Dark Theme Specification
  static ThemeData get darkTheme {
    final ColorScheme colorScheme = const ColorScheme.dark(
      primary: _darkPrimary,
      secondary: _darkSecondary,
      tertiary: _darkTertiary,
      background: _darkBackground,
      surface: _darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onBackground: _darkOnSurface,
      onSurface: _darkOnSurface,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: _buildTextTheme(_darkOnSurface),
      
      // Status bar style configuration
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _darkOnSurface, size: 24),
        actionsIconTheme: IconThemeData(color: _darkOnSurface, size: 24),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: _darkOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // Premium rounded cards with subtle borders
      cardTheme: CardTheme(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1.0,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      // Beautiful inputs with modern dark states
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: _darkPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        labelStyle: TextStyle(color: _darkOnSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: _darkOnSurface.withOpacity(0.4)),
        prefixIconColor: _darkOnSurface.withOpacity(0.5),
        suffixIconColor: _darkOnSurface.withOpacity(0.5),
      ),

      // Elegant Button Styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) return Colors.white.withOpacity(0.12);
              return null;
            },
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: _darkPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Modern Tab Bar
      tabBarTheme: TabBarTheme(
        labelColor: _darkPrimary,
        unselectedLabelColor: _darkOnSurface.withOpacity(0.5),
        indicatorColor: _darkPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // Minimal Bottom Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: _darkPrimary.withOpacity(0.15),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: _darkPrimary);
          }
          return IconThemeData(color: _darkOnSurface.withOpacity(0.5));
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: _darkPrimary, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: _darkOnSurface.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500);
        }),
        elevation: 8,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _darkPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Custom extensions for Find My-style overlays (blurs, dark mode gradients)
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          glassBackground: const Color(0xFF151D30).withOpacity(0.70),
          glassBorder: Colors.white.withOpacity(0.08),
          backgroundGradient: const [
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
          mapOverlayBackground: const Color(0xFF0B0F19).withOpacity(0.85),
          blurSigma: 20.0,
          activePulseColor: _darkPrimary.withOpacity(0.25),
        ),
      ],
    );
  }
}
