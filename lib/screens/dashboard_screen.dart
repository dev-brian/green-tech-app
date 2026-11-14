import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../services/alerts_controller.dart';
import '../services/greenhouse_session.dart';
import '../services/mock_zone_status_source.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import '../widgets/live_clock.dart';
import '../widgets/que_hacer_section.dart';
import '../widgets/zone_section.dart';
import 'alerts_screen.dart';
import 'greenhouse_gate_screen.dart';
import 'profile_screen.dart';
import 'sensor_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SensorDataController _controller = SensorDataController.instance;
  final GreenhouseSession _session = GreenhouseSession.instance;

  int _navIndex = 0;

  void _cambiarInvernadero() {
    if (_session.isDemo) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const GreenhouseGateScreen(cambiar: true),
    ));
  }

  /// Reintenta la suscripción a los sensores (los datos llegan por stream;
  /// SensorDataController.start se llama en main.dart).
  Future<void> _loadAll() => _controller.start();

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    final screens = [null, const AlertsScreen(), const ProfileScreen()];
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screens[index]!))
        .then((_) {
      if (mounted) setState(() => _navIndex = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: ValueListenableBuilder<Greenhouse?>(
          valueListenable: _session.current,
          builder: (context, gh, _) => InkWell(
            key: const Key('cambiar_invernadero'),
            onTap: gh == null || _session.isDemo ? null : _cambiarInvernadero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GREEN TECH',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                if (gh != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          gh.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (!_session.isDemo)
                        const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (_controller.source case final MockZoneStatusSource mock)
            _buildScenarioMenu(mock),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            onPressed: () => AppThemeController.toggleTheme(),
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
                        child: ListView(
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
                            if (_session.isDemo) ...[
                              _buildDemoBanner(isDark),
                              const SizedBox(height: 14),
                            ],
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
                                    ResumenHoy(zonas: ordenadas, now: now),
                                    QueHacerSection(
                                      zonas: ordenadas,
                                      now: now,
                                      onOpenZone: _openZone,
                                    ),
                                    const SizedBox(height: 22),
                                    const TituloSeccion('Tus zonas'),
                                    for (final zone in ordenadas) ...[
                                      const SizedBox(height: 12),
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
                          ],
                        ),
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
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Inicio'),
          NavigationDestination(
              icon: _AlertasIcon(), label: 'Alertas'),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtextColor),
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
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
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
              style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtextColor),
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
                style: GoogleFonts.plusJakartaSans(
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

  /// Modo demo: los datos son de prueba, no de un invernadero real.
  Widget _buildDemoBanner(bool isDark) {
    final color = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Row(
      children: [
        Icon(Icons.science_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Modo demostración: datos de prueba. Usa el matraz para '
            'forzar escenarios.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: color),
          ),
        ),
      ],
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
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
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

/// Ícono de Alertas con el número de alertas abiertas (Observer sobre
/// AlertsController).
class _AlertasIcon extends StatelessWidget {
  const _AlertasIcon();

  @override
  Widget build(BuildContext context) {
    final alerts = AlertsController.instance;
    return ValueListenableBuilder<List<AlertItem>>(
      valueListenable: alerts.alerts,
      builder: (context, _, __) {
        final n = alerts.activas;
        return Badge(
          isLabelVisible: n > 0,
          label: Text(n > 99 ? '99+' : '$n'),
          backgroundColor: AppColors.critico,
          child: const Icon(Icons.notifications_outlined),
        );
      },
    );
  }
}
