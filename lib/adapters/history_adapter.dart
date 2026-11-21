import '../models/history.dart';
import '../models/zone_status.dart';
import 'firestore_dates.dart';
import 'zone_status_adapter.dart';

/// Adapter de `readings` (lecturas crudas, 2.2) y `readingsHourly`
/// (promedios por hora, 2.3) a series por variable.
class HistoryAdapter {
  HistoryAdapter._();

  /// `readings/{id}`: `{zoneId, timestamp, airTemp: 24.1, ph: 6.1, …}`.
  static Map<HydroVariable, List<HistoryPoint>> fromReadings(
      Iterable<Map<String, dynamic>> docs) {
    final out = {for (final v in HydroVariable.values) v: <HistoryPoint>[]};
    for (final d in docs) {
      final t = parseFecha(d['timestamp']);
      if (t == null) continue;
      for (final v in HydroVariable.values) {
        final raw = d[ZoneStatusAdapter.fieldOf(v)];
        if (raw is num) out[v]!.add(HistoryPoint(t, raw.toDouble()));
      }
    }
    for (final s in out.values) {
      s.sort((a, b) => a.time.compareTo(b.time));
    }
    return out;
  }

  /// `readingsHourly/{zoneId}_{yyyyMMddHH}`:
  /// `{zoneId, hour, count, airTemp: {avg, min, max}, …}`.
  static Map<HydroVariable, List<HistoryPoint>> fromHourly(
      Iterable<Map<String, dynamic>> docs) {
    final out = {for (final v in HydroVariable.values) v: <HistoryPoint>[]};
    for (final d in docs) {
      final t = parseFecha(d['hour']);
      if (t == null) continue;
      for (final v in HydroVariable.values) {
        final raw = d[ZoneStatusAdapter.fieldOf(v)];
        if (raw is Map && raw['avg'] is num) {
          out[v]!.add(HistoryPoint(
            t,
            (raw['avg'] as num).toDouble(),
            min: (raw['min'] as num?)?.toDouble(),
            max: (raw['max'] as num?)?.toDouble(),
          ));
        }
      }
    }
    for (final s in out.values) {
      s.sort((a, b) => a.time.compareTo(b.time));
    }
    return out;
  }
}
