import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import '../widgets/chart_widget.dart';
import '../widgets/live_clock.dart';
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
  final SensorDataController _controller = SensorDataController.instance;

  List<ChartPoint> _chartPoints = [];
  bool _chartLoading = false;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    // Los sensores ya vienen por stream (SensorDataController.start en
    // main.dart); aquí solo cargamos el clima y la gráfica de pronóstico.
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    await _controller.loadRealWeather();
    if (_controller.weatherError.value == null) {
      await _loadChart();
    }
  }

  /// Reintenta la suscripción a los sensores y recarga clima + gráfica.
  Future<void> _loadAll() async {
    await _controller.start();
    await _loadWeather();
  }

  Future<void> _loadChart() async {
    setState(() => _chartLoading = true);
    try {
      final chart = await _controller.api
          .getHistorico(metric: 'temperatura', rango: 'hoy');
      if (!mounted) return;
      setState(() {
        _chartPoints = chart;
        _chartLoading = false;
      });
    } catch (_) {
      // Si falla la mini-gráfica no bloqueamos el resto del Dashboard;
      // simplemente se queda vacía con su propio mensaje de "sin datos".
      if (!mounted) return;
      setState(() {
        _chartPoints = [];
        _chartLoading = false;
      });
    }
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
      if (mounted) setState(() => _navIndex = 0);
    });
  }

  Future<void> _changeLocation() async {
    final result = await showLocationPicker(
      context: context,
      api: _controller.api,
      initialLocation: _controller.currentLocation,
    );

    if (result != null && result.trim().isNotEmpty) {
      await _loadWeather();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
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
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            onPressed: () => AppThemeController.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Cambiar ubicación',
            onPressed: _changeLocation,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _controller.loading,
            builder: (context, loading, _) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loading ? null : _loadAll,
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, loading, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: _controller.error,
            builder: (context, errorMsg, __) {
              return ValueListenableBuilder<SensorReading?>(
                valueListenable: _controller.currentReading,
                builder: (context, reading, ___) {
                  if (loading && reading == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (errorMsg != null && reading == null) {
                    return _buildErrorState(errorMsg, isDark);
                  }

                  if (reading == null) {
                    return _buildWaitingState(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: _loadAll,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final wide = constraints.maxWidth > 650;
                          final maxCrossExtent = wide ? 240.0 : 180.0;

                          return ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              if (errorMsg != null) ...[
                                _buildInlineErrorBanner(errorMsg, isDark),
                                const SizedBox(height: 14),
                              ],
                              // Se reconstruye cada 10 s para que "hace X"
                              // avance y detectar si el sensor dejó de reportar.
                              LiveClock(
                                builder: (context, now) {
                                  final stale = lecturaDesactualizada(
                                      reading.timestamp, now);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                    _buildHeaderSection(reading, isDark, now, stale),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Sensores en tiempo real',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    GridView(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: maxCrossExtent,
                                        mainAxisSpacing: 14,
                                        crossAxisSpacing: 14,
                                        mainAxisExtent: 145,
                                      ),
                                      children: [
                                        SensorCard(
                                          label: 'Temperatura',
                                          value: reading.temperatura.toStringAsFixed(1),
                                          unit: '°C',
                                          icon: Icons.thermostat,
                                          estado: reading.estadoTemperatura,
                                          onTap: _goToDetail,
                                          desactualizado: stale,
                                        ),
                                        SensorCard(
                                          label: 'Humedad ambiental',
                                          value: reading.humedadAire.toStringAsFixed(0),
                                          unit: '%',
                                          icon: Icons.water_drop_outlined,
                                          estado: reading.estadoHumedadAire,
                                          onTap: _goToDetail,
                                          desactualizado: stale,
                                        ),
                                        SensorCard(
                                          label: 'Humedad del suelo',
                                          value: reading.humedadSuelo.toStringAsFixed(0),
                                          unit: '%',
                                          icon: Icons.grass,
                                          estado: reading.estadoHumedadSuelo,
                                          onTap: _goToDetail,
                                          desactualizado: stale,
                                        ),
                                        _buildSensorInfoCard(reading, isDark),
                                      ],
                                    ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildWeatherCard(isDark),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pronóstico próximas horas',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
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
                              Container(
                                decoration: NeumorphismDecoration.extruded(
                                  context: context,
                                  isDark: isDark,
                                  borderRadius: 18,
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 18, 18, 14),
                                  child: _chartLoading
                                      ? SizedBox(
                                          height: wide ? 260 : 200,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                                color: AppColors.primary),
                                          ),
                                        )
                                      : ChartWidget(
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
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        indicatorColor: AppColors.mintAccent.withValues(alpha: 0.3),
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

  Widget _buildErrorState(String message, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.critico, size: 42),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar los sensores',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Firebase responde pero `telemetria/{sensorId}` aún no existe: el
  /// simulador (o el ESP32) todavía no ha enviado ninguna lectura.
  Widget _buildWaitingState(bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_off, color: AppColors.secondary, size: 42),
            const SizedBox(height: 12),
            Text(
              'Esperando datos del sensor…',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Aún no llegan lecturas de ${_controller.sensorId}. '
              'Aparecerán aquí automáticamente.',
              style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineErrorBanner(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.critico.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.critico.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.critico, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudo actualizar los sensores: $message',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.critico),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
      SensorReading reading, bool isDark, DateTime now, bool stale) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 18,
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
                          color: subtextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Monitoreo de cultivo',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
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
                stale
                    ? _buildStatusChip(
                        'Estado', 'Sin datos recientes', subtextColor, isDark)
                    : _buildStatusChip(
                        'Estado',
                        AppColors.labelForEstado(reading.estadoGeneral),
                        AppColors.forEstado(reading.estadoGeneral),
                        isDark),
                _buildStatusChip(
                    'Ubicación', reading.ubicacion, AppColors.secondary, isDark),
                _buildStatusChip(
                    'Última',
                    formatHace(reading.timestamp, now),
                    stale ? AppColors.accentOrange : subtextColor,
                    isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3), width: 1),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: textColor,
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

  /// Clima exterior de la ubicación elegida (OpenWeather). Es contexto
  /// para el productor; no se mezcla con las lecturas de los sensores.
  Widget _buildWeatherCard(bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ValueListenableBuilder<SensorReading?>(
      valueListenable: _controller.weather,
      builder: (context, clima, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _controller.weatherError,
          builder: (context, weatherError, __) {
            final String detalle;
            if (clima != null) {
              detalle = '${clima.temperatura.toStringAsFixed(1)}°C · '
                  'Humedad ${clima.humedadAire.toStringAsFixed(0)}%';
            } else if (weatherError != null) {
              detalle = 'No se pudo cargar el clima';
            } else {
              detalle = 'Cargando clima…';
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: NeumorphismDecoration.extruded(
                context: context,
                isDark: isDark,
                borderRadius: 18,
              ),
              child: Row(
                children: [
                  const Icon(Icons.wb_cloudy_outlined,
                      color: AppColors.secondary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clima en ${_controller.currentLocation}',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          detalle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: weatherError != null && clima == null
                                ? AppColors.critico
                                : subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _changeLocation,
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _goToDetail() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SensorDetailScreen()));
  }

  Widget _buildSensorInfoCard(SensorReading reading, bool isDark) {
    return InkWell(
      onTap: _goToDetail,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: NeumorphismDecoration.glowingExtruded(
          isDark: isDark,
          accentColor: AppColors.secondary,
          borderRadius: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.sensors, color: AppColors.secondary, size: 24),
                Icon(Icons.arrow_forward_ios, color: AppColors.secondary, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ver detalle',
                  style: GoogleFonts.poppins(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'del sensor',
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
