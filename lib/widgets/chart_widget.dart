import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].value),
    );

    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b) + 2;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: showLabels,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: showLabels,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (v, meta) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.primaryDark,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
