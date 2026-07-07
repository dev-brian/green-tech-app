import 'package:flutter/material.dart';
import '../models/sensor_model.dart';
import '../utils/colors.dart';

/// Tarjeta principal del Dashboard: ícono, valor grande y color de estado.
/// Diseñada para leerse de un vistazo en campo, con sol directo.
class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final EstadoNivel estado;
  final VoidCallback? onTap;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.estado,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forEstado(estado);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Icon(AppColors.iconForEstado(estado), color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 2),
                Text(unit, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
