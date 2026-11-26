import '../config/variable_config.dart';
import '../models/history.dart';
import '../models/zone_status.dart';

String historyToCsv(List<ZoneHistory> historias) {
  final b = StringBuffer('\uFEFF');
  b.writeln('zona,variable,fecha_hora,promedio,minimo,maximo');
  for (final h in historias) {
    for (final v in HydroVariable.values) {
      for (final p in h[v]) {
        b.writeln([
          _celda(h.zoneId),
          _celda(v.spec.label),
          p.time.toIso8601String(),
          p.value,
          p.min ?? '',
          p.max ?? '',
        ].join(','));
      }
    }
  }
  return b.toString();
}

String _celda(String s) => s.contains(',') || s.contains('"')
    ? '"${s.replaceAll('"', '""')}"'
    : s;