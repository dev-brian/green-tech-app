import 'zone_status.dart';

/// Rangos del histórico (HU de histórico de la PWA: 24 h / 7 d / 30 d).
enum HistoryRange {
  h24('24 h', Duration(hours: 24)),
  d7('7 d', Duration(days: 7)),
  d30('30 d', Duration(days: 30));

  const HistoryRange(this.label, this.duration);
  final String label;
  final Duration duration;
}

/// Un punto de la gráfica. En 7 y 30 días es el promedio de una hora y trae
/// también el mínimo y el máximo de esa hora.
class HistoryPoint {
  final DateTime time;
  final double value;
  final double? min;
  final double? max;

  const HistoryPoint(this.time, this.value, {this.min, this.max});
}

/// Histórico de una zona: una serie por variable, ordenada por hora.
class ZoneHistory {
  final String zoneId;
  final HistoryRange range;
  final Map<HydroVariable, List<HistoryPoint>> series;

  const ZoneHistory({
    required this.zoneId,
    required this.range,
    required this.series,
  });

  List<HistoryPoint> operator [](HydroVariable v) => series[v] ?? const [];

  bool get isEmpty => series.values.every((s) => s.isEmpty);
}

/// Promedia [points] (ya ordenados) en cubetas de [bucket]. Sirve para no
/// dibujar 1 440 puntos en la gráfica de 24 h.
List<HistoryPoint> agruparPor(List<HistoryPoint> points, Duration bucket) {
  if (points.isEmpty) return const [];
  final ms = bucket.inMilliseconds;
  final out = <HistoryPoint>[];
  var start = points.first.time.millisecondsSinceEpoch ~/ ms;
  var acc = <HistoryPoint>[];

  void flush() {
    if (acc.isEmpty) return;
    final sum = acc.fold<double>(0, (s, p) => s + p.value);
    out.add(HistoryPoint(
      DateTime.fromMillisecondsSinceEpoch(start * ms),
      sum / acc.length,
      min: acc.map((p) => p.min ?? p.value).reduce((a, b) => a < b ? a : b),
      max: acc.map((p) => p.max ?? p.value).reduce((a, b) => a > b ? a : b),
    ));
  }

  for (final p in points) {
    final b = p.time.millisecondsSinceEpoch ~/ ms;
    if (b != start) {
      flush();
      acc = [];
      start = b;
    }
    acc.add(p);
  }
  flush();
  return out;
}
