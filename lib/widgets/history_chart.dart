import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../config/variable_config.dart';
import '../models/history.dart';
import '../models/zone_status.dart';
import '../repositories/history_repository.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';

/// Histórico de una zona: selector de variable y de rango (24 h / 7 d /
/// 30 d) y la gráfica. Se carga al abrir y al cambiar de rango; no se
/// actualiza en vivo (para eso están las tarjetas de arriba).
class HistorySection extends StatefulWidget {
  const HistorySection({
    super.key,
    required this.repository,
    required this.greenhouseId,
    required this.zoneId,
  });

  final HistoryRepository repository;
  final String greenhouseId;
  final String zoneId;

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  HydroVariable _variable = HydroVariable.ph;
  HistoryRange _range = HistoryRange.h24;
  late Future<ZoneHistory> _future = _cargar();

  Future<ZoneHistory> _cargar() => widget.repository
      .fetch(widget.greenhouseId, widget.zoneId, _range);

  @override
  void didUpdateWidget(HistorySection old) {
    super.didUpdateWidget(old);
    if (old.zoneId != widget.zoneId || old.greenhouseId != widget.greenhouseId) {
      _future = _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeumorphismDecoration.extruded(
          context: context, isDark: isDark, borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Histórico',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          SegmentedButton<HistoryRange>(
            segments: [
              for (final r in HistoryRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_range},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _range = s.first;
              _future = _cargar();
            }),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final v in HydroVariable.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('historico_${v.name}'),
                      avatar: Icon(v.spec.icon, size: 16),
                      label: Text(v.spec.label),
                      selected: v == _variable,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _variable = v),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: FutureBuilder<ZoneHistory>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return _mensaje(
                      'No se pudo cargar el histórico. Revisa tu conexión.',
                      subtextColor);
                }
                final puntos = snap.data![_variable];
                if (puntos.isEmpty) {
                  return _mensaje(
                      _range == HistoryRange.h24
                          ? 'Sin lecturas en las últimas 24 h.'
                          : 'Aún no hay promedios por hora para este rango. '
                              'Aparecerán cuando el backend los publique.',
                      subtextColor);
                }
                return HistoryChart(
                    points: puntos, variable: _variable, range: _range);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mensaje(String texto, Color color) => Center(
        child: Text(texto,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: color)),
      );
}

/// Línea del promedio y, si los hay, banda de mínimo a máximo.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.points,
    required this.variable,
    required this.range,
  });

  final List<HistoryPoint> points;
  final HydroVariable variable;
  final HistoryRange range;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final grid = (isDark ? AppColors.darkBorder : AppColors.border)
        .withValues(alpha: 0.6);
    final spec = variable.spec;
    double x(DateTime t) => t.millisecondsSinceEpoch / 60000;

    final banda = points.any((p) => p.min != null && p.max != null);
    final linea = LineChartBarData(
      spots: [for (final p in points) FlSpot(x(p.time), p.value)],
      isCurved: true,
      preventCurveOverShooting: true,
      color: AppColors.secondary,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: !banda,
        color: AppColors.secondary.withValues(alpha: 0.12),
      ),
    );
    LineChartBarData borde(double Function(HistoryPoint) f) => LineChartBarData(
          spots: [for (final p in points) FlSpot(x(p.time), f(p))],
          isCurved: true,
          preventCurveOverShooting: true,
          color: AppColors.secondary.withValues(alpha: 0.25),
          barWidth: 1,
          dotData: const FlDotData(show: false),
        );

    final etiquetaX = range == HistoryRange.h24
        ? DateFormat('HH:mm')
        : DateFormat('dd/MM');
    final intervaloX = switch (range) {
      HistoryRange.h24 => 6 * 60.0,
      HistoryRange.d7 => 24 * 60.0 * 2,
      HistoryRange.d30 => 24 * 60.0 * 7,
    };

    return LineChart(
      LineChartData(
        lineBarsData: [
          linea,
          if (banda) borde((p) => p.min ?? p.value),
          if (banda) borde((p) => p.max ?? p.value),
        ],
        betweenBarsData: [
          if (banda)
            BetweenBarsData(
              fromIndex: 1,
              toIndex: 2,
              color: AppColors.secondary.withValues(alpha: 0.12),
            ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(spec.format(v),
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: subtextColor)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: intervaloX,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  etiquetaX.format(
                      DateTime.fromMillisecondsSinceEpoch((v * 60000).round())),
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: subtextColor),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                s.barIndex == 0
                    ? LineTooltipItem(
                        '${spec.display(s.y)}\n${etiquetaX.format(DateTime.fromMillisecondsSinceEpoch((s.x * 60000).round()))}',
                        GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      )
                    : null,
            ],
          ),
        ),
      ),
    );
  }
}
