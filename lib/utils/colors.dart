import 'package:flutter/material.dart';
import '../models/sensor_model.dart';

/// Paleta central de la app. Todo el semáforo de colores vive aquí
/// para que sea fácil de ajustar sin tocar las pantallas.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF316B43);
  static const Color primaryLight = Color(0xFF5F9B6B);
  static const Color primaryDark = Color(0xFF1F462F);
  static const Color accent = Color(0xFF8FAF77);
  static const Color background = Color(0xFFF7F4EA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2E7);
  static const Color border = Color(0xFFD8D3C8);
  static const Color textPrimary = Color(0xFF25332B);
  static const Color textSecondary = Color(0xFF6D7469);
  static const Color hint = Color(0xFF9AA091);

  static const Color normal = Color(0xFF2F7F4F);
  static const Color alerta = Color(0xFFB68B34);
  static const Color critico = Color(0xFFB03D3D);

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
        return Icons.check_circle;
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
  final colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceVariant,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    error: AppColors.critico,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: colorScheme,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primaryDark,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.primaryDark,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: AppColors.primaryDark),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 26,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.textSecondary),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.hint),
    ),
  );
}
