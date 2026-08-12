import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../utils/colors.dart';

/// Fila de la lista de Alertas según la Guía de Estilos Green Tech
class AlertTile extends StatelessWidget {
  final AlertItem alert;

  const AlertTile({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forEstado(alert.nivel);
    final fecha = DateFormat('dd/MM/yyyy · HH:mm').format(alert.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
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
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (alert.activa ? AppColors.accentOrange : AppColors.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              alert.activa ? 'Activa' : 'Resuelta',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: alert.activa ? AppColors.accentOrange : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
