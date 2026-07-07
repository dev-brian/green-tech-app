import 'package:flutter/material.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/chart_widget.dart';
import '../widgets/sensor_card.dart';
import 'alerts_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'sensor_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();

  SensorReading? _reading;
  List<ChartPoint> _chartPoints = [];
  bool _loading = true;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final reading = await _api.getCurrentReading();
    final chart = await _api.getHistorico(metric: 'temperatura', rango: 'hoy');
    if (!mounted) return;
    setState(() {
      _reading = reading;
      _chartPoints = chart;
      _loading = false;
    });
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    final screens = [null, const HistoryScreen(), const AlertsScreen(), const ProfileScreen()];
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screens[index]!)).then((_) {
      setState(() => _navIndex = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GREEN TECH'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: _loading || _reading == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildEstadoBanner(_reading!),
                  const SizedBox(height: 20),
                  Text('Sensores en tiempo real', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      SensorCard(
                        label: 'Temperatura',
                        value: _reading!.temperatura.toStringAsFixed(1),
                        unit: '°C',
                        icon: Icons.thermostat,
                        estado: _reading!.estadoTemperatura,
                        onTap: _goToDetail,
                      ),
                      SensorCard(
                        label: 'Humedad ambiental',
                        value: _reading!.humedadAire.toStringAsFixed(0),
                        unit: '%',
                        icon: Icons.water_drop_outlined,
                        estado: _reading!.estadoHumedadAire,
                        onTap: _goToDetail,
                      ),
                      SensorCard(
                        label: 'Humedad del suelo',
                        value: _reading!.humedadSuelo.toStringAsFixed(0),
                        unit: '%',
                        icon: Icons.grass,
                        estado: _reading!.estadoHumedadSuelo,
                        onTap: _goToDetail,
                      ),
                      _buildSensorInfoCard(_reading!),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Últimas 24 horas', style: Theme.of(context).textTheme.titleLarge),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        ),
                        child: const Text('Ver histórico'),
                      ),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
                      child: ChartWidget(points: _chartPoints, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Alertas'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  void _goToDetail() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SensorDetailScreen()));
  }

  Widget _buildEstadoBanner(SensorReading reading) {
    final color = AppColors.forEstado(reading.estadoGeneral);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(AppColors.iconForEstado(reading.estadoGeneral), color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading.mensajeEstado,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text('${reading.ubicacion} · ${reading.sensorId}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorInfoCard(SensorReading reading) {
    return InkWell(
      onTap: _goToDetail,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.sensors, color: Colors.white, size: 26),
            SizedBox(height: 10),
            Text('Ver detalle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Text('del sensor', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
