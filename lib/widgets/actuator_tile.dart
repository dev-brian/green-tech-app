import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/actuator_model.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'live_clock.dart';

/// Fila de estado de un equipo (HU-M03): ícono, nombre, "LED" y switch.
///
/// Es solo de lectura: el switch refleja la bandera que publica el ESP32
/// (o el simulador) en Firestore, pero no se puede accionar desde la app.
class ActuatorTile extends StatelessWidget {
  final Actuador actuador;

  /// Hora de referencia para "hace X" (la provee un [LiveClock]).
  final DateTime now;

  const ActuatorTile({super.key, required this.actuador, required this.now});

  static IconData iconFor(TipoActuador tipo) => switch (tipo) {
        TipoActuador.bomba => Icons.water,
        TipoActuador.ventilador => Icons.wind_power,
        TipoActuador.calefactor => Icons.local_fire_department_outlined,
        TipoActuador.luz => Icons.lightbulb_outline,
        TipoActuador.otro => Icons.settings_input_component,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final encendido = actuador.encendido;
    final estadoColor = encendido ? AppColors.primary : subtextColor;
    final estadoTexto = encendido ? 'Encendido' : 'Apagado';
    final actualizado = actuador.actualizado;
    final detalle = actualizado == null
        ? estadoTexto
        : '$estadoTexto · ${formatHace(actualizado, now).toLowerCase()}';

    return Semantics(
      container: true,
      label: '${actuador.nombre}: $estadoTexto',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: NeumorphismDecoration.extruded(
            context: context,
            isDark: isDark,
            borderRadius: 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(iconFor(actuador.tipo), color: estadoColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actuador.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusLed(encendido: encendido),
              const SizedBox(width: 4),
              // Refleja el estado con colores normales (un Switch
              // deshabilitado se vería gris aunque esté encendido), pero
              // IgnorePointer impide accionarlo: la app solo observa.
              IgnorePointer(
                child: Switch(
                  value: encendido,
                  onChanged: (_) {},
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "LED" de estado: verde brillante con resplandor si está encendido,
/// gris apagado si no. Anima el cambio para que se note en tiempo real.
class StatusLed extends StatelessWidget {
  final bool encendido;
  final double size;

  const StatusLed({super.key, required this.encendido, this.size = 14});

  static const Color colorEncendido = AppColors.mintAccent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final apagado = isDark ? AppColors.darkBorder : AppColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: encendido ? colorEncendido : apagado,
        boxShadow: encendido
            ? [
                BoxShadow(
                  color: colorEncendido.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
    );
  }
}
