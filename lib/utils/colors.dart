import 'package:flutter/material.dart';
import '../models/sensor_model.dart';

/// Paleta central de la app. Todo el semáforo de colores vive aquí
/// para que sea fácil de ajustar sin tocar las pantallas.
class AppColors {
  AppColors._();

  // Marca
  static const Color primary = Color(0xFF2E7D32); // Verde GREEN TECH
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color background = Color(0xFFF6F8F6);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1C1C1C);
  static const Color textSecondary = Color(0xFF6B6B6B);

  // Semáforo de estados (CRÍTICO para agricultores)
  static const Color normal = Color(0xFF2E7D32); // 🟢
  static const Color alerta = Color(0xFFF9A825); // 🟡
  static const Color critico = Color(0xFFD32F2F); // 🔴

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
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.textPrimary),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
