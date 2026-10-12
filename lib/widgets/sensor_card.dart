import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';

/// Tarjeta del Dashboard con Soft Neumorphism adaptada a Modo Claro y Oscuro.
///
/// Muestra el valor con su color de semáforo. Si [desactualizado] es true
/// (el sensor dejó de reportar), el semáforo se apaga a gris para no dar
/// una falsa sensación de "todo normal" con datos viejos.
class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final EstadoNivel estado;
  final VoidCallback? onTap;
  final bool desactualizado;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.estado,
    this.onTap,
    this.desactualizado = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final statusColor =
        desactualizado ? subtextColor : AppColors.forEstado(estado);
    final isNormal = !desactualizado && estado == EstadoNivel.normal;
    final statusIcon =
        desactualizado ? Icons.sync_problem : AppColors.iconForEstado(estado);
    final statusLabel =
        desactualizado ? 'Sin datos' : AppColors.labelForEstado(estado);

    final neumorphicDecoration = isNormal
        ? NeumorphismDecoration.glowingExtruded(
            isDark: isDark,
            accentColor: AppColors.primary,
            borderRadius: 18,
          )
        : NeumorphismDecoration.extruded(
            context: context,
            isDark: isDark,
            borderRadius: 18,
            border: Border.all(
              color: statusColor.withValues(alpha: isDark ? 0.4 : 0.6),
              width: 1.5,
            ),
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: neumorphicDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 6),
                // Flexible: en tarjetas angostas (≈155 px en teléfono) la
                // etiqueta se recorta en vez de desbordar la fila.
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
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
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: desactualizado ? subtextColor : textColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
