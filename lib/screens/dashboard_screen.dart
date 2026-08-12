import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/chart_widget.dart';
import '../widgets/location_picker_dialog.dart';
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
    final screens = [
      null,
      const HistoryScreen(),
      const AlertsScreen(),
      const ProfileScreen()
    ];
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screens[index]!))
        .then((_) {
      setState(() => _navIndex = 0);
    });
  }

  Future<void> _changeLocation() async {
    final result = await showLocationPicker(
      context: context,
      api: _api,
      initialLocation: _api.currentLocation,
    );

    if (result != null && result.trim().isNotEmpty) {
      _api.setLocation(result.trim());
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'GREEN TECH',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Cambiar ubicación',
            onPressed: _changeLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: _loading || _reading == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 650;
                    final maxCrossExtent = wide ? 240.0 : 180.0;

                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        _buildHeaderSection(_reading!),
                        const SizedBox(height: 24),
                        Text(
                          'Sensores en tiempo real',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: maxCrossExtent,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 145,
                          ),
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
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Últimas 24 horas',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const HistoryScreen()),
                              ),
                              child: Text(
                                'Ver histórico',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 18, 18, 14),
                            child: ChartWidget(
                              points: _chartPoints,
                              color: AppColors.primary,
                              height: wide ? 260 : 200,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        indicatorColor: AppColors.mintAccent.withValues(alpha: 0.4),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.secondary),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.show_chart), label: 'Histórico'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: 'Alertas'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(SensorReading reading) {
    return Card(
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.eco, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Monitoreo de cultivo',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              runSpacing: 10,
              spacing: 10,
              children: [
                _buildStatusChip(
                    'Estado',
                    AppColors.labelForEstado(reading.estadoGeneral),
                    AppColors.forEstado(reading.estadoGeneral)),
                _buildStatusChip(
                    'Ubicación', reading.ubicacion, AppColors.secondary),
                _buildStatusChip(
                    'Última',
                    DateFormat('dd/MM · HH:mm').format(reading.timestamp),
                    AppColors.textSecondary),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToDetail() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SensorDetailScreen()));
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
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.sensors, color: Colors.white, size: 24),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ver detalle',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'del sensor',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
