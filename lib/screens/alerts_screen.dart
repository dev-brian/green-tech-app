import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sensor_model.dart';
import '../services/alerts_controller.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import '../widgets/alert_tile.dart';

/// Filtro por estado de la bandeja.
enum FiltroEstado {
  activas('Activas'),
  atendidas('Atendidas'),
  resueltas('Resueltas'),
  todas('Todas');

  const FiltroEstado(this.label);
  final String label;

  bool acepta(AlertItem a) => switch (this) {
        FiltroEstado.activas => a.status == AlertStatus.nueva,
        FiltroEstado.atendidas => a.status == AlertStatus.atendida,
        FiltroEstado.resueltas => a.status == AlertStatus.autoResuelta,
        FiltroEstado.todas => true,
      };
}

/// Filtro por severidad.
enum FiltroSeveridad {
  todas('Toda severidad'),
  criticas('Críticas'),
  avisos('Avisos');

  const FiltroSeveridad(this.label);
  final String label;

  bool acepta(AlertItem a) => switch (this) {
        FiltroSeveridad.todas => true,
        FiltroSeveridad.criticas => a.nivel == EstadoNivel.critico,
        FiltroSeveridad.avisos => a.nivel == EstadoNivel.alerta,
      };
}

/// Aplica los tres filtros de la bandeja.
List<AlertItem> filtrarAlertas(
  List<AlertItem> alerts, {
  FiltroEstado estado = FiltroEstado.todas,
  FiltroSeveridad severidad = FiltroSeveridad.todas,
  String? zona,
}) =>
    [
      for (final a in alerts)
        if (estado.acepta(a) &&
            severidad.acepta(a) &&
            (zona == null || a.zoneId == zona))
          a,
    ];

/// Bandeja de alertas: las mismas que la PWA, leídas de
/// `greenhouses/{id}/alerts`. La app no calcula alertas; solo permite
/// atenderlas desde campo.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.controller, this.uid});

  /// Para pruebas; por defecto [AlertsController.instance].
  final AlertsController? controller;

  /// Para pruebas; por defecto el usuario de la sesión.
  final String? uid;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AlertsController _controller =
      widget.controller ?? AlertsController.instance;

  FiltroEstado _estado = FiltroEstado.activas;
  FiltroSeveridad _severidad = FiltroSeveridad.todas;
  String? _zona;

  Future<void> _atender(AlertItem alert) async {
    final uid = widget.uid ??
        GreenhouseSession.instance.uid ??
        (GreenhouseSession.instance.isDemo ? 'demo' : null);
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Alerta atendida. Si no hay señal, se sincroniza al volver.'),
      duration: Duration(seconds: 3),
    ));
    // No se espera al servidor: sin red el Future no termina hasta
    // reconectar, y la alerta ya se ve atendida.
    final ok = await _controller.attend(alert, uid);
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo atender la alerta. Revisa tus permisos.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Alertas de Cultivo',
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
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, loading, _) {
          return ValueListenableBuilder<List<AlertItem>>(
            valueListenable: _controller.alerts,
            builder: (context, allAlerts, __) {
              if (loading && allAlerts.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final zonas = {for (final a in allAlerts) a.zoneId}.toList()
                ..sort();
              final visibles = filtrarAlertas(allAlerts,
                  estado: _estado, severidad: _severidad, zona: _zona);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      ValueListenableBuilder<String?>(
                        valueListenable: _controller.error,
                        builder: (context, err, _) => err == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Text(
                                  err,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.estadoTexto(
                                        EstadoNivel.critico,
                                        isDark: isDark),
                                  ),
                                ),
                              ),
                      ),
                      _buildFiltros(zonas, isDark),
                      Expanded(
                        child: visibles.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _estado == FiltroEstado.activas
                                        ? 'No hay alertas activas. Todo en orden.'
                                        : 'No hay alertas para mostrar',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: subtextColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: visibles.length,
                                itemBuilder: (context, i) => AlertTile(
                                  alert: visibles[i],
                                  onAttend: visibles[i].activa
                                      ? () => _atender(visibles[i])
                                      : null,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFiltros(List<String> zonas, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    Widget chip(String label, bool selected, VoidCallback onTap,
            {Color color = AppColors.secondary}) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : textColor,
              ),
            ),
            selected: selected,
            onSelected: (_) => onTap(),
            selectedColor: color.withValues(alpha: isDark ? 0.25 : 0.15),
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected
                    ? color
                    : (isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in FiltroEstado.values)
                chip(f.label, _estado == f, () => setState(() => _estado = f)),
            ]),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in FiltroSeveridad.values)
                chip(f.label, _severidad == f,
                    () => setState(() => _severidad = f),
                    color: f == FiltroSeveridad.criticas
                        ? AppColors.critico
                        : f == FiltroSeveridad.avisos
                            ? AppColors.accentOrange
                            : AppColors.secondary),
              if (zonas.length > 1) ...[
                const SizedBox(width: 4),
                DropdownButton<String?>(
                  value: zonas.contains(_zona) ? _zona : null,
                  hint: const Text('Todas las zonas'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Todas las zonas')),
                    for (final z in zonas)
                      DropdownMenuItem(value: z, child: Text(z)),
                  ],
                  onChanged: (z) => setState(() => _zona = z),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}
