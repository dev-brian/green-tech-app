import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/actuator_state.dart';
import '../repositories/actuators_repository.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'live_clock.dart';

/// Estado de los 4 actuadores de la zona, en tiempo real y solo lectura
/// (los controla el backend o el admin desde la PWA).
class ActuatorsCard extends StatefulWidget {
  const ActuatorsCard({
    super.key,
    required this.repository,
    required this.greenhouseId,
    required this.zoneId,
  });

  final ActuatorsRepository repository;
  final String greenhouseId;
  final String zoneId;

  @override
  State<ActuatorsCard> createState() => _ActuatorsCardState();
}

class _ActuatorsCardState extends State<ActuatorsCard> {
  // Se guarda el stream para no volver a suscribirse en cada lectura nueva
  // de la zona (el Detalle se reconstruye con cada una).
  late Stream<ZoneActuators?> _stream = _crear();

  Stream<ZoneActuators?> _crear() =>
      widget.repository.watch(widget.greenhouseId, widget.zoneId);

  @override
  void didUpdateWidget(ActuatorsCard old) {
    super.didUpdateWidget(old);
    if (old.zoneId != widget.zoneId ||
        old.greenhouseId != widget.greenhouseId ||
        old.repository != widget.repository) {
      _stream = _crear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeumorphismDecoration.extruded(
          context: context, isDark: isDark, borderRadius: 20),
      child: StreamBuilder<ZoneActuators?>(
        stream: _stream,
        builder: (context, snap) {
          final data = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Actuadores',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
                  ),
                  Text('Solo lectura',
                      style: GoogleFonts.inter(fontSize: 12, color: subtextColor)),
                ],
              ),
              const SizedBox(height: 8),
              if (snap.hasError)
                Text('No se pudo leer el estado de los actuadores.',
                    style: GoogleFonts.inter(fontSize: 13, color: subtextColor))
              else if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (data == null)
                Text('Esta zona aún no reporta actuadores.',
                    style: GoogleFonts.inter(fontSize: 13, color: subtextColor))
              else ...[
                for (final kind in ActuatorKind.values)
                  _fila(kind, data[kind], isDark, textColor, subtextColor),
                if (data.updatedAt != null)
                  LiveClock(
                    builder: (context, now) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          'Actualizado: ${formatHace(data.updatedAt!, now)}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: subtextColor)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _fila(ActuatorKind kind, ActuatorStatus? st, bool isDark,
      Color textColor, Color subtextColor) {
    final on = st?.on;
    final color = on == true
        ? AppColors.primary
        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(kind.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(kind.label,
                style: GoogleFonts.inter(fontSize: 14, color: textColor)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              on == null ? 'Sin dato' : (on ? 'Encendido' : 'Apagado'),
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
