import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import '../widgets/location_picker_dialog.dart';

/// Muestra la misma lectura activa que el Dashboard (clima real o
/// simulado vía sliders) — ya no hace su propio fetch por separado, para
/// que nunca se desincronice de lo que se ve en la pantalla principal.
class SensorDetailScreen extends StatefulWidget {
  const SensorDetailScreen({super.key});

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  final SensorDataController _controller = SensorDataController.instance;

  Future<void> _changeLocation() async {
    final result = await showLocationPicker(
      context: context,
      api: _controller.api,
      initialLocation: _controller.currentLocation,
    );

    if (result != null && result.trim().isNotEmpty) {
      await _controller.loadRealWeather(location: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Detalle del Sensor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: () => AppThemeController.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Cambiar ubicación',
            onPressed: _changeLocation,
          ),
        ],
      ),
      body: ValueListenableBuilder<SensorReading?>(
        valueListenable: _controller.currentReading,
        builder: (context, r, _) {
          if (r == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          return RefreshIndicator(
            onRefresh: () => _controller.loadRealWeather(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (_controller.isSimulating)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange
                                .withValues(alpha: isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune,
                                  color: AppColors.accentOrange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mostrando valores simulados desde el Dashboard',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      decoration: NeumorphismDecoration.extruded(
                        context: context,
                        isDark: isDark,
                        borderRadius: 20,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.mintAccent.withValues(alpha: isDark ? 0.2 : 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.memory,
                                    color: AppColors.secondary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ID del sensor',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: subtextColor,
                                        ),
                                      ),
                                      Text(
                                        r.sensorId,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 28),
                            _infoRow(
                              Icons.place_outlined,
                              'Ubicación',
                              r.ubicacion,
                              isDark,
                            ),
                            const SizedBox(height: 12),
                            _infoRow(
                              Icons.access_time,
                              'Última actualización',
                              _hace(r.timestamp),
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Lecturas actuales',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _dataTile(
                      'Temperatura',
                      '${r.temperatura.toStringAsFixed(1)}°C',
                      r.estadoTemperatura,
                      Icons.thermostat,
                      isDark,
                    ),
                    _dataTile(
                      'Humedad del aire',
                      '${r.humedadAire.toStringAsFixed(0)}%',
                      r.estadoHumedadAire,
                      Icons.water_drop_outlined,
                      isDark,
                    ),
                    _dataTile(
                      'Humedad del suelo',
                      '${r.humedadSuelo.toStringAsFixed(0)}%',
                      r.estadoHumedadSuelo,
                      Icons.grass,
                      isDark,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _hace(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds} seg';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return DateFormat('dd/MM HH:mm').format(t);
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            color: subtextColor,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _dataTile(
      String label, String value, EstadoNivel estado, IconData icon, bool isDark) {
    final color = AppColors.forEstado(estado);
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
