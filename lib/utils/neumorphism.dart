import 'package:flutter/material.dart';

import 'colors.dart';

/// Superficies del sistema de diseño "invernadero".
///
/// Conserva el nombre y la API de la antigua decoración neumórfica para no
/// tocar cada pantalla, pero ahora dibuja tarjetas planas con borde fino y
/// una sola sombra suave (SKILL.md, sección 3).
class NeumorphismDecoration {
  NeumorphismDecoration._();

  static List<BoxShadow> _shadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF344626).withValues(alpha: 0.08),
          offset: const Offset(0, 8),
          blurRadius: 24,
        ),
      ];

  /// Tarjeta.
  static BoxDecoration extruded({
    required BuildContext context,
    required bool isDark,
    double borderRadius = 24.0,
    Color? baseColor,
    Border? border,
  }) {
    return BoxDecoration(
      color: baseColor ?? (isDark ? AppColors.darkSurface : AppColors.surface),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ??
          Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
          ),
      boxShadow: _shadow(isDark),
    );
  }

  /// Tarjeta destacada: el borde toma el color de acento; el fondo no
  /// cambia (el estado nunca pinta la tarjeta completa).
  static BoxDecoration glowingExtruded({
    required bool isDark,
    required Color accentColor,
    double borderRadius = 24.0,
  }) {
    return BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: accentColor, width: 1.5),
      boxShadow: _shadow(isDark),
    );
  }

  /// Pozo: filas, campos de entrada y contenedores internos.
  static BoxDecoration inset({
    required bool isDark,
    double borderRadius = 14.0,
    Color? baseColor,
  }) {
    return BoxDecoration(
      color: baseColor ?? (isDark ? AppColors.darkWell : AppColors.well),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.border,
      ),
    );
  }
}
