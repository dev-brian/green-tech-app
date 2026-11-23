import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Tope de documentos por consulta. Una zona escribe 1 lectura por minuto
  /// (24 h = 1 440) y 1 promedio por hora (30 días = 720); el margen cubre
  /// reintentos del backend sin dejar la consulta abierta.
  static const int limiteLecturas = 1500;
  static const int limitePromedios = 800;

  /// Si Firestore no responde en este tiempo, la pantalla muestra el error
  /// con reintento en vez de quedarse cargando.
  static const Duration timeout = Duration(seconds: 10);

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
      final docs = await _query(gh.collection('readings'), 'timestamp', zoneId, since,
          limiteLecturas);
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
          await _query(gh.collection('readingsHourly'), 'hour', zoneId, since,
          limitePromedios);
      history = ZoneHistory(
        zoneId: zoneId,
        range: range,
        series: HistoryAdapter.fromHourly(docs),
      );
    }
    _cache[key] = (now, history);
    return history;
  }

  /// Consulta una sola zona en el rango pedido, con límite y tiempo de
  /// espera. Usa el índice compuesto (zoneId, campo de tiempo) declarado en
  /// firestore.indexes.json del repo de la PWA; si faltara, Firestore
  /// responde failed-precondition y la pantalla muestra el error (antes se
  /// leían todas las zonas del periodo y se filtraban en el celular).
  Future<List<Map<String, dynamic>>> _query(
    CollectionReference<Map<String, dynamic>> col,
    String timeField,
    String zoneId,
    DateTime since,
    int limite,
  ) async {
    final snap = await col
        .where('zoneId', isEqualTo: zoneId)
        .where(timeField, isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy(timeField)
        .limit(limite)
        .get()
        .timeout(timeout);
    return [for (final d in snap.docs) d.data()];
  }
}
