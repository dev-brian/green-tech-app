import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';

/// Fila de la bandeja de Alertas con Soft Neumorphism.
///
/// Si [onAttend] no es null (alerta abierta) muestra el botón "Atender".
class AlertTile extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onAttend;

  const AlertTile({super.key, required this.alert, this.onAttend});

  static String estadoLabel(AlertItem a) => switch (a.status) {
        AlertStatus.nueva => 'Activa',
        AlertStatus.atendida => 'Atendida',
        AlertStatus.autoResuelta => 'Resuelta',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forEstado(alert.nivel);
    final formato = DateFormat('dd/MM/yyyy · HH:mm');

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final badgeColor = switch (alert.status) {
      AlertStatus.nueva => AppColors.accentOrange,
      AlertStatus.atendida => AppColors.secondary,
      AlertStatus.autoResuelta => AppColors.primary,
    };

    final detalle = [
      formato.format(alert.fecha),
      if (alert.status == AlertStatus.atendida && alert.attendedAt != null)
        'atendida ${DateFormat('HH:mm').format(alert.attendedAt!)}',
      if (alert.status == AlertStatus.autoResuelta && alert.resolvedAt != null)
        'resuelta ${DateFormat('HH:mm').format(alert.resolvedAt!)}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 16,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppColors.iconForEstado(alert.nivel), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.mensaje,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detalle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estadoLabel(alert),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          if (onAttend != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: Key('atender_${alert.id}'),
                onPressed: onAttend,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Atender'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
