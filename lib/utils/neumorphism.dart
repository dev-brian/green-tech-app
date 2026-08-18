import 'package:flutter/material.dart';

/// Helper para generar decoraciones neumórficas (Soft Neumorphism)
/// adaptadas dinámicamente al tema Claro u Oscuro.
class NeumorphismDecoration {
  NeumorphismDecoration._();

  /// Tarjetas y Botones Extruidos (Relieve 3D Suave)
  static BoxDecoration extruded({
    required BuildContext context,
    required bool isDark,
    double borderRadius = 18.0,
    Color? baseColor,
    Border? border,
  }) {
    final bgColor = baseColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFEAEFF5));

    final topLeftLight = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.45)
        : Colors.white;

    final bottomRightShadow = isDark
        ? const Color(0xFF070C14).withValues(alpha: 0.75)
        : const Color(0xFFA3B1C6).withValues(alpha: 0.55);

    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border,
      boxShadow: [
        BoxShadow(
          color: topLeftLight,
          offset: const Offset(-4, -4),
          blurRadius: 10,
        ),
        BoxShadow(
          color: bottomRightShadow,
          offset: const Offset(4, 4),
          blurRadius: 10,
        ),
      ],
    );
  }

  /// Tarjetas destacadas neumórficas con resplandor de acento (Accent Glow)
  static BoxDecoration glowingExtruded({
    required bool isDark,
    required Color accentColor,
    double borderRadius = 18.0,
  }) {
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEAEFF5);

    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: accentColor.withValues(alpha: isDark ? 0.4 : 0.6),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: isDark ? 0.25 : 0.35),
          offset: const Offset(-2, -2),
          blurRadius: 10,
        ),
        BoxShadow(
          color: isDark
              ? const Color(0xFF070C14).withValues(alpha: 0.7)
              : const Color(0xFFA3B1C6).withValues(alpha: 0.5),
          offset: const Offset(4, 4),
          blurRadius: 10,
        ),
      ],
    );
  }

  /// Efecto Hendido / Inset para campos de entrada y contenedores activos
  static BoxDecoration inset({
    required bool isDark,
    double borderRadius = 14.0,
    Color? baseColor,
  }) {
    final bgColor = baseColor ??
        (isDark ? const Color(0xFF162032) : const Color(0xFFE2E8F0));

    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        width: 1,
      ),
    );
  }
}
