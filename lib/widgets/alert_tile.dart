import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../utils/colors.dart';

/// Fila de la lista de Alertas: color de nivel, mensaje, fecha y estado.
class AlertTile extends StatelessWidget {
  final AlertItem alert;

  const AlertTile({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forEstado(alert.nivel);
    final fecha = DateFormat('dd/MM/yyyy · HH:mm').format(alert.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(AppColors.iconForEstado(alert.nivel), color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.mensaje,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(fecha,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (alert.activa ? AppColors.critico : AppColors.normal)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              alert.activa ? 'Activa' : 'Resuelta',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: alert.activa ? AppColors.critico : AppColors.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
