import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

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
    final r = await _api.getCurrentReading();
    if (!mounted) return;
    setState(() => _reading = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del sensor')),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.memory, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID del sensor', style: Theme.of(context).textTheme.bodyMedium),
                                    Text(r.sensorId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          _infoRow(Icons.place_outlined, 'Ubicación', r.ubicacion),
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
                  const SizedBox(height: 20),
                  Text('Lecturas actuales', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _dataTile('Temperatura', '${r.temperatura.toStringAsFixed(1)}°C', r.estadoTemperatura, Icons.thermostat),
                  _dataTile('Humedad del aire', '${r.humedadAire.toStringAsFixed(0)}%', r.estadoHumedadAire, Icons.water_drop_outlined),
                  _dataTile('Humedad del suelo', '${r.humedadSuelo.toStringAsFixed(0)}%', r.estadoHumedadSuelo, Icons.grass),
                ],
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
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _dataTile(String label, String value, EstadoNivel estado, IconData icon) {
    final color = AppColors.forEstado(estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }
}
