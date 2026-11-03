import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../services/api_service.dart';
import '../services/mock_zone_status_source.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import '../widgets/chart_widget.dart';
import '../widgets/live_clock.dart';
import '../widgets/location_picker_dialog.dart';
import '../widgets/variable_card.dart';
import '../widgets/zone_section.dart';
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
          if (_controller.source case final MockZoneStatusSource mock)
            _buildScenarioMenu(mock),
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
              return ValueListenableBuilder<Map<String, ZoneStatus>>(
                valueListenable: _controller.zones,
                builder: (context, zones, ___) {
                  if (loading && zones.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (errorMsg != null && zones.isEmpty) {
                    return _buildErrorState(errorMsg, isDark);
                  }

                  if (zones.isEmpty) {
                    return _buildWaitingState(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: _loadAll,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final wide = constraints.maxWidth > 650;
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: _controller.offline,
                                builder: (context, offline, _) => offline
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: _buildOfflineBanner(
                                            _ultimaLectura(zones), isDark),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (errorMsg != null) ...[
                                _buildInlineErrorBanner(errorMsg, isDark),
                                const SizedBox(height: 14),
                              ],
                              // Se reconstruye cada 10 s para que "hace X"
                              // avance y detectar zonas que dejaron de reportar.
                              LiveClock(
                                builder: (context, now) {
                                  final ordenadas =
                                      zonasPorSeveridad(zones.values, now);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildSummary(ordenadas, now, isDark),
                                      for (final zone in ordenadas) ...[
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration:
                                              NeumorphismDecoration.extruded(
                                            context: context,
                                            isDark: isDark,
                                            borderRadius: 20,
                                          ),
                                          child: ZoneSection(
                                            zone: zone,
                                            now: now,
                                            onOpen: () => _openZone(zone.zoneId),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              _buildWeatherCard(isDark),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Pronóstico próximas horas',
                                      style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const HistoryScreen()),
                                    ),
                                    child: Text(
                                      'Histórico',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.secondaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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

  /// La fuente responde pero `greenhouses/{id}/state/latest` aún no existe:
  /// el backend todavía no ha publicado el estado de ninguna zona.
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
              'Esperando datos del invernadero…',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Aún no llega el estado de las zonas. '
              'Aparecerá aquí automáticamente.',
              style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Hora del dato más reciente entre todas las zonas.
  DateTime _ultimaLectura(Map<String, ZoneStatus> zones) => zones.values
      .map((z) => z.timestamp)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  /// Sin red: Firestore sigue entregando la caché local. Se avisa para que
  /// el productor sepa que los valores pueden no ser los actuales.
  Widget _buildOfflineBanner(DateTime ultimaLectura, bool isDark) {
    final color = AppColors.estadoTexto(EstadoNivel.alerta, isDark: isDark);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin conexión · datos de las '
                '${DateFormat('HH:mm').format(ultimaLectura)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineErrorBanner(String message, bool isDark) {
    final color = AppColors.estadoTexto(EstadoNivel.critico, isDark: isDark);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudo actualizar los sensores: $message',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Resumen arriba de las zonas: estado de la peor zona y cuántas zonas
  /// necesitan atención.
  Widget _buildSummary(List<ZoneStatus> ordenadas, DateTime now, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final peor = ordenadas.first;
    final atencion = ordenadas
        .where((z) =>
            lecturaDesactualizada(z.timestamp, now) ||
            z.overallLevel != EstadoNivel.normal)
        .length;
    final total = ordenadas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado del invernadero',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EstadoPill(
              estado: peor.overallLevel,
              desactualizada: lecturaDesactualizada(peor.timestamp, now),
            ),
            Text(
              atencion == 0
                  ? '$total ${total == 1 ? 'zona' : 'zonas'} en orden'
                  : '$atencion de $total ${total == 1 ? 'zona' : 'zonas'} '
                      'requieren atención',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: subtextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Clima exterior de la ubicación elegida (OpenWeather). Es contexto
  /// para el productor; no se mezcla con las lecturas de los sensores.
  Widget _buildWeatherCard(bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ValueListenableBuilder<CurrentWeather?>(
      valueListenable: _controller.weather,
      builder: (context, clima, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _controller.weatherError,
          builder: (context, weatherError, __) {
            final String detalle;
            if (clima != null) {
              detalle = '${clima.temperature.toStringAsFixed(1)}°C · '
                  'Humedad ${clima.humidity.toStringAsFixed(0)}%';
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
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.secondaryDark,
                    ),
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

  /// Menú para forzar escenarios de la fuente de prueba.
  Widget _buildScenarioMenu(MockZoneStatusSource mock) {
    return PopupMenuButton<MockScenario>(
      icon: const Icon(Icons.science_outlined),
      tooltip: 'Escenario de prueba',
      onSelected: (s) => setState(() => mock.scenario = s),
      itemBuilder: (_) => [
        for (final s in MockScenario.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == mock.scenario,
            child: Text(s.label),
          ),
      ],
    );
  }

  /// Abre el detalle de [zoneId] (el Detalle muestra la zona activa).
  void _openZone(String zoneId) {
    _controller.selectZone(zoneId);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SensorDetailScreen()));
  }
}
