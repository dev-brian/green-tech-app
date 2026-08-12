import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';

/// Paleta central de la app según la Guía de Estilos UI/UX: Green Tech
class AppColors {
  AppColors._();

  // Colorimetría oficial del handoff
  static const Color primary = Color(0xFF32A852); // Organic Green
  static const Color secondary = Color(0xFF0056B3); // Tech Blue
  static const Color mintAccent = Color(0xFF84F2D0); // Mint Accent
  static const Color surface = Color(0xFFFFFFFF); // Surface White
  static const Color background = Color(0xFFF8F9FA); // Background Light
  static const Color textPrimary = Color(0xFF2C3E50); // Charcoal Text
  static const Color accentOrange = Color(0xFFF39C12); // Accent Orange

  // Colores secundarios y variantes
  static const Color primaryLight = Color(0xFF5CDA7E);
  static const Color primaryDark = Color(0xFF237D3B);
  static const Color textSecondary = Color(0xFF5A6B7C);
  static const Color hint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color surfaceVariant = Color(0xFFEDF2F7);

  // Estados de Sensores / Alertas
  static const Color normal = Color(0xFF32A852); // Organic Green
  static const Color alerta = Color(0xFFF39C12); // Accent Orange
  static const Color critico = Color(0xFFE74C3C); // Crítico / Destructivo

  static Color forEstado(EstadoNivel estado) {
    switch (estado) {
      case EstadoNivel.normal:
        return normal;
      case EstadoNivel.alerta:
        return alerta;
      case EstadoNivel.critico:
        return critico;
    }
  }

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

/// Tema global de Material 3 usado en main.dart
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.textSecondary,
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
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: baseTextTheme.copyWith(
      // H1 - Poppins Black (900) - 24px/32px
      displayLarge: poppinsTextTheme.displayLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
      // H1 Móvil / Headline
      headlineLarge: poppinsTextTheme.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
      // H2 - Poppins Bold (700) - 20px/24px
      headlineMedium: poppinsTextTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      // H3 - Poppins SemiBold (600) - 18px/20px
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
      // Body Regular (400) - 16px
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      // Body Medium (500) - 14px
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      // Caption Light (300) - 12px
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: AppColors.textSecondary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: poppinsTextTheme.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.secondary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.hint),
    ),
  );
}

