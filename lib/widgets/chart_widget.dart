import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sensor_model.dart';
import '../utils/colors.dart';

/// Gráfica de línea simple y limpia, pensada para leerse rápido.
/// Se usa tanto en el mini-gráfico del Dashboard como en el Histórico.
class ChartWidget extends StatelessWidget {
  final List<ChartPoint> points;
  final Color color;
  final double height;
  final bool showLabels;

  const ChartWidget({
    super.key,
    required this.points,
    this.color = AppColors.primary,
    this.height = 160,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Sin datos disponibles')),
      );
    }

    // Convertir tiempos a double (ms) para el eje X
    final spots = points
        .map((p) => FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.value))
        .toList();

    final minX = spots.first.x;
    final maxX = spots.last.x;

    final values = points.map((p) => p.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 2;

    String formatTime(double ms) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
      return DateFormat.Hm().format(dt); // HH:mm
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: showLabels,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: showLabels,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (v, meta) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showLabels,
                interval: (maxX - minX) / (spots.length > 4 ? 4 : spots.length),
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    formatTime(v),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.primaryDark,
              getTooltipItems: (touchedSpots) => touchedSpots.map((t) {
                final timeLabel = formatTime(t.x);
                return LineTooltipItem(
                  '${t.y.toStringAsFixed(1)}\n$timeLabel',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
