import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/variable_config.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';

/// Tarjeta de una variable de la zona.
///
/// El estado se comunica con color, ícono Y texto ("Normal", "Alerta",
/// "Crítico"), nunca solo con color. Si la lectura de la zona es vieja
/// ([desactualizada]) o la variable no llegó, la tarjeta pasa a gris: un
/// semáforo verde con datos viejos daría una falsa sensación de normalidad.
class VariableCard extends StatelessWidget {
  const VariableCard({
    super.key,
    required this.variable,
    required this.measurement,
    this.desactualizada = false,
    this.onTap,
  });

  final HydroVariable variable;
  final Measurement? measurement;
  final bool desactualizada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spec = variable.spec;
    final m = measurement;
    final gris = desactualizada || m == null;

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final color = gris
        ? AppColors.sinDatos(isDark: isDark)
        : AppColors.estadoTexto(m.level, isDark: isDark);

    final (IconData statusIcon, String statusLabel) = switch ((m, desactualizada)) {
      (null, _) => (Icons.help_outline_rounded, 'Sin datos'),
      (_, true) => (Icons.schedule_rounded, 'Sin datos recientes'),
      (final m?, false) =>
        (AppColors.iconForEstado(m.level), AppColors.labelForEstado(m.level)),
    };
    final value = m == null ? '—' : spec.format(m.value);
    final destacado = !gris && m.level != EstadoNivel.normal;

    return Semantics(
      button: onTap != null,
      label: '${spec.label}: $value ${spec.unit}. $statusLabel',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            // ≥ 48 px de alto en cualquier caso: toda la tarjeta es el
            // objetivo táctil.
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(14),
            decoration: NeumorphismDecoration.extruded(
              context: context,
              isDark: isDark,
              borderRadius: 16,
              border: Border.all(
                color: destacado
                    ? color
                    : (isDark ? AppColors.darkBorder : AppColors.border),
                width: destacado ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(spec.icon, size: 20, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        spec.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: subtextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: gris ? subtextColor : textColor,
                        ),
                      ),
                      if (spec.unit.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          spec.unit,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _StatusPill(
                  icon: statusIcon,
                  label: statusLabel,
                  color: color,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora de estado: ícono + texto sobre un fondo teñido del mismo color.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora pública para el encabezado de zona y el resumen del Dashboard.
class EstadoPill extends StatelessWidget {
  const EstadoPill({super.key, required this.estado, this.desactualizada = false});

  final EstadoNivel estado;
  final bool desactualizada;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _StatusPill(
      icon: desactualizada
          ? Icons.schedule_rounded
          : AppColors.iconForEstado(estado),
      label: desactualizada
          ? 'Sin datos recientes'
          : AppColors.labelForEstado(estado),
      color: desactualizada
          ? AppColors.sinDatos(isDark: isDark)
          : AppColors.estadoTexto(estado, isDark: isDark),
      isDark: isDark,
    );
  }
}
