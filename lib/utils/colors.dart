import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_model.dart';

/// Controlador global para cambiar de tema (Modo Claro / Oscuro) dinámicamente
class AppThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggleTheme() async {
    final newMode = themeMode.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', newMode == ThemeMode.dark);
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;
}

/// Paleta Bio-Tech y Neumórfica de la app
class AppColors {
  AppColors._();

  // Colorimetría Bio-Tech vibrante
  static const Color primary = Color(0xFF10B981); // Bio Emerald
  static const Color primaryDark = Color(0xFF059669);
  static const Color secondary = Color(0xFF0284C7); // Tech Sapphire
  static const Color secondaryDark = Color(0xFF0369A1);
  static const Color mintAccent = Color(0xFF34D399); // Mint Glow Accent
  static const Color accentOrange = Color(0xFFF59E0B); // Warning Amber
  static const Color critico = Color(0xFFEF4444); // Danger Rose

  // Fondos y Superficies Neumórficas (Modo Claro)
  static const Color background = Color(0xFFEAEFF5);
  static const Color surface = Color(0xFFEAEFF5);
  static const Color textPrimary = Color(0xFF1E293B);
  // #475569: 6.6:1 sobre el fondo (el anterior #64748B daba 4.1:1, < AA).
  static const Color textSecondary = Color(0xFF475569);
  static const Color border = Color(0xFFCBD5E1);

  // Fondos y Superficies Neumórficas (Modo Oscuro)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);

  static Color forEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return primary;
      case EstadoNivel.alerta:
        return accentOrange;
      case EstadoNivel.critico:
        return critico;
    }
  }

  // Texto e íconos de estado con contraste WCAG AA (≥ 4.5:1) sobre las
  // tarjetas, también sobre la píldora teñida con el mismo color. Los
  // colores de marca de arriba (primary, accentOrange, critico) no llegan
  // a 4.5:1 sobre el fondo claro, así que no se usan para texto pequeño.
  // Contraste en claro sobre #EAEFF5 / en oscuro sobre #1E293B:
  static const Color _okLight = Color(0xFF065F46); // 6.6:1
  static const Color _warnLight = Color(0xFF92400E); // 6.1:1
  static const Color _critLight = Color(0xFFB91C1C); // 5.6:1
  static const Color _staleLight = Color(0xFF475569); // 6.6:1
  static const Color _okDark = Color(0xFF34D399); // 7.6:1
  static const Color _warnDark = Color(0xFFFBBF24); // 8.8:1
  static const Color _critDark = Color(0xFFFCA5A5); // 7.7:1
  static const Color _staleDark = Color(0xFFCBD5E1); // 9.9:1

  /// Color para texto, íconos y bordes de estado (semáforo).
  static Color estadoTexto(EstadoNivel estado, {required bool isDark}) =>
      switch (estado) {
        EstadoNivel.normal => isDark ? _okDark : _okLight,
        EstadoNivel.alerta => isDark ? _warnDark : _warnLight,
        EstadoNivel.critico => isDark ? _critDark : _critLight,
      };

  /// Gris para lecturas viejas o ausentes.
  static Color sinDatos({required bool isDark}) =>
      isDark ? _staleDark : _staleLight;

  static IconData iconForEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return Icons.check_circle_rounded;
      case EstadoNivel.alerta:
        return Icons.warning_rounded;
      case EstadoNivel.critico:
        return Icons.error_rounded;
    }
  }

  static String labelForEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return 'Normal';
      case EstadoNivel.alerta:
        return 'Alerta';
      case EstadoNivel.critico:
        return 'Crítico';
    }
  }
}

/// Tema global de Material 3 en Modo Claro
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    outline: AppColors.border,
    error: AppColors.critico,
    onError: Colors.white,
  );

  final baseTextTheme = GoogleFonts.interTextTheme();
  final poppinsTextTheme = GoogleFonts.poppinsTextTheme();

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: poppinsTextTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: baseTextTheme.copyWith(
      displayLarge: poppinsTextTheme.displayLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
      headlineMedium: poppinsTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: poppinsTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: poppinsTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Tema global de Material 3 en Modo Oscuro
ThemeData buildDarkAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    outline: AppColors.darkBorder,
    error: AppColors.critico,
    onError: Colors.white,
  );

  final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
  final poppinsTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF0B1120),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: poppinsTextTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: baseTextTheme.copyWith(
      displayLarge: poppinsTextTheme.displayLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.darkTextPrimary,
      ),
      headlineMedium: poppinsTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.darkTextPrimary,
      ),
      titleLarge: poppinsTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      titleMedium: poppinsTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.darkTextPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.darkTextSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.darkTextSecondary,
      ),
    ),
  );
}


