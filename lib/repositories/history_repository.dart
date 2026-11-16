import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../adapters/history_adapter.dart';
import '../models/history.dart';

/// Histórico de una zona para las gráficas del Detalle.
abstract class HistoryRepository {
  Future<ZoneHistory> fetch(
    String greenhouseId,
    String zoneId,
    HistoryRange range,
  );
}

/// Lee el histórico de Firestore bajo demanda (no en tiempo real) y lo
/// guarda 5 minutos en memoria para no gastar lecturas del plan Spark cada
/// vez que se abre el Detalle.
///
/// - 24 h: `readings` (una lectura por minuto), promediada cada 5 min.
/// - 7 y 30 días: `readingsHourly` (un promedio por hora).
class FirestoreHistoryRepository implements HistoryRepository {
  FirestoreHistoryRepository({
    FirebaseFirestore? firestore,
    this.cacheTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  })  : _firestore = firestore,
        _now = clock ?? DateTime.now;

  final FirebaseFirestore? _firestore;
  final Duration cacheTtl;
  final DateTime Function() _now;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  final Map<String, (DateTime, ZoneHistory)> _cache = {};

  /// true después de que Firestore rechazó la consulta compuesta por falta
  /// del índice `zoneId ASC, timestamp ASC`: desde entonces se usa la
  /// consulta simple y se filtra la zona en el celular.
  bool _sinIndice = false;

  @override
  Future<ZoneHistory> fetch(
    String greenhouseId,
    String zoneId,
    HistoryRange range,
  ) async {
    final key = '$greenhouseId/$zoneId/${range.name}';
    final now = _now();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.$1) < cacheTtl) {
      return cached.$2;
    }

    final since = now.subtract(range.duration);
    final gh = _db.collection('greenhouses').doc(greenhouseId);
    final ZoneHistory history;
    if (range == HistoryRange.h24) {
      final docs = await _query(gh.collection('readings'), 'timestamp', zoneId, since);
      final raw = HistoryAdapter.fromReadings(docs);
      history = ZoneHistory(
        zoneId: zoneId,
        range: range,
        series: {
          for (final e in raw.entries)
            e.key: agruparPor(e.value, const Duration(minutes: 5)),
        },
      );
    } else {
      final docs =
          await _query(gh.collection('readingsHourly'), 'hour', zoneId, since);
      history = ZoneHistory(
        zoneId: zoneId,
        range: range,
        series: HistoryAdapter.fromHourly(docs),
      );
    }
    _cache[key] = (now, history);
    return history;
  }

  Future<List<Map<String, dynamic>>> _query(
    CollectionReference<Map<String, dynamic>> col,
    String timeField,
    String zoneId,
    DateTime since,
  ) async {
    final desde = Timestamp.fromDate(since);
    if (!_sinIndice) {
      try {
        final snap = await col
            .where('zoneId', isEqualTo: zoneId)
            .where(timeField, isGreaterThanOrEqualTo: desde)
            .orderBy(timeField)
            .get();
        return [for (final d in snap.docs) d.data()];
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition') rethrow;
        debugPrint('HistoryRepository: falta el índice compuesto de '
            '${col.id} (zoneId, $timeField); se filtra en el celular');
        _sinIndice = true;
      }
    }
    final snap = await col
        .where(timeField, isGreaterThanOrEqualTo: desde)
        .orderBy(timeField)
        .get();
    return [
      for (final d in snap.docs)
        if (d.data()['zoneId'] == zoneId) d.data(),
    ];
  }
}
