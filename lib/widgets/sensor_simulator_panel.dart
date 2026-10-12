import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';

/// Panel de simulación de sensores para el Dashboard.
///
/// Mientras no haya hardware ESP32 conectado, este panel deja mover 3
/// sliders (temperatura, humedad del aire, humedad del suelo) partiendo
/// del clima real de la ubicación elegida, para poder probar cómo
/// reacciona toda la app (semáforo, tarjetas, alertas y notificaciones)
/// ante distintas condiciones sin esperar a tener el IoT real.
class SensorSimulatorPanel extends StatefulWidget {
  final SensorReading reading;
  final bool isDark;

  const SensorSimulatorPanel({
    super.key,
    required this.reading,
    required this.isDark,
  });

  @override
  State<SensorSimulatorPanel> createState() => _SensorSimulatorPanelState();
}

class _SensorSimulatorPanelState extends State<SensorSimulatorPanel> {
  late double _temp;
  late double _humedadAire;
  late double _humedadSuelo;

  @override
  void initState() {
    super.initState();
    _syncFromReading();
  }

  @override
  void didUpdateWidget(covariant SensorSimulatorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la lectura cambió desde afuera (nuevo clima real cargado, o se
    // restableció la simulación), refleja esos valores en los sliders.
    if (oldWidget.reading.temperatura != widget.reading.temperatura ||
        oldWidget.reading.humedadAire != widget.reading.humedadAire ||
        oldWidget.reading.humedadSuelo != widget.reading.humedadSuelo) {
      _syncFromReading();
    }
  }

  void _syncFromReading() {
    // clamp() en `num` devuelve `num`, no `double` — hay que convertir de
    // vuelta explícitamente para poder asignarlo a estos campos `double`.
    _temp = widget.reading.temperatura.clamp(-10, 50).toDouble();
    _humedadAire = widget.reading.humedadAire.clamp(0, 100).toDouble();
    _humedadSuelo = widget.reading.humedadSuelo.clamp(0, 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final controller = SensorDataController.instance;

    return Container(
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: widget.isDark,
        borderRadius: 18,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simular lecturas de sensores',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              ValueListenableBuilder<SensorReading?>(
                valueListenable: controller.currentReading,
                builder: (context, _, __) {
                  if (!controller.isSimulating) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: () => controller.resetSimulation(),
                    child: Text(
                      'Usar clima real',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Text(
            'Aún no hay sensores ESP32 conectados: mueve los controles para '
            'probar cómo se ve la app con distintas condiciones.',
            style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
          ),
          _slider(
            label: 'Temperatura',
            value: _temp,
            min: -10,
            max: 50,
            unit: '°C',
            color: AppColors.forEstado(widget.reading.estadoTemperatura),
            textColor: textColor,
            onChanged: (v) => setState(() => _temp = v),
            onChangeEnd: (v) => controller.setSimulatedValues(temperatura: v),
          ),
          _slider(
            label: 'Humedad ambiental',
            value: _humedadAire,
            min: 0,
            max: 100,
            unit: '%',
            color: AppColors.forEstado(widget.reading.estadoHumedadAire),
            textColor: textColor,
            onChanged: (v) => setState(() => _humedadAire = v),
            onChangeEnd: (v) => controller.setSimulatedValues(humedadAire: v),
          ),
          _slider(
            label: 'Humedad del suelo',
            value: _humedadSuelo,
            min: 0,
            max: 100,
            unit: '%',
            color: AppColors.forEstado(widget.reading.estadoHumedadSuelo),
            textColor: textColor,
            onChanged: (v) => setState(() => _humedadSuelo = v),
            onChangeEnd: (v) => controller.setSimulatedValues(humedadSuelo: v),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required Color textColor,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}$unit',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              inactiveTrackColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
