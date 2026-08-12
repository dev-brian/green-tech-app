import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/location_picker_dialog.dart';

class SensorDetailScreen extends StatefulWidget {
  const SensorDetailScreen({super.key});

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  final ApiService _api = ApiService();
  SensorReading? _reading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.getCurrentReading();
      if (!mounted) return;
      setState(() => _reading = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el detalle: $e')),
      );
    }
  }

  Future<void> _changeLocation() async {
    final result = await showLocationPicker(
      context: context,
      api: _api,
      initialLocation: _api.currentLocation,
    );

    if (result != null && result.trim().isNotEmpty) {
      _api.setLocation(result.trim());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Detalle del Sensor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Cambiar ubicación',
            onPressed: _changeLocation,
          ),
        ],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Card(
                        color: AppColors.surface,
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
                                      color: AppColors.mintAccent.withValues(alpha: 0.3),
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
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          r.sensorId,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: AppColors.textPrimary,
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
                              ),
                              const SizedBox(height: 12),
                              _infoRow(
                                Icons.access_time,
                                'Última actualización',
                                _hace(r.timestamp),
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _dataTile(
                        'Temperatura',
                        '${r.temperatura.toStringAsFixed(1)}°C',
                        r.estadoTemperatura,
                        Icons.thermostat,
                      ),
                      _dataTile(
                        'Humedad del aire',
                        '${r.humedadAire.toStringAsFixed(0)}%',
                        r.estadoHumedadAire,
                        Icons.water_drop_outlined,
                      ),
                      _dataTile(
                        'Humedad del suelo',
                        '${r.humedadSuelo.toStringAsFixed(0)}%',
                        r.estadoHumedadSuelo,
                        Icons.grass,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _hace(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds} seg';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return DateFormat('dd/MM HH:mm').format(t);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _dataTile(
      String label, String value, EstadoNivel estado, IconData icon) {
    final color = AppColors.forEstado(estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.textPrimary,
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
