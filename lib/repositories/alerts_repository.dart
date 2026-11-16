import 'package:cloud_firestore/cloud_firestore.dart';

import '../adapters/alert_adapter.dart';
import '../models/sensor_model.dart';

/// Una emisión de la bandeja de alertas.
class AlertsSnapshot {
  final List<AlertItem> alerts;
  final bool fromCache;

  const AlertsSnapshot({required this.alerts, this.fromCache = false});
}

/// Alertas de un invernadero, creadas por el motor del backend.
abstract class AlertsRepository {
  /// Las 100 alertas más recientes, de la más nueva a la más vieja.
  Stream<AlertsSnapshot> watch(String greenhouseId);

  /// Marca la alerta como atendida por [uid]. Sin internet, Firestore la
  /// encola y la sube al volver la señal.
  Future<void> attend(String greenhouseId, String alertId, String uid);
}

class FirestoreAlertsRepository implements AlertsRepository {
  FirestoreAlertsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  static const int limite = 100;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _alerts(String greenhouseId) =>
      _db.collection('greenhouses').doc(greenhouseId).collection('alerts');

  @override
  Stream<AlertsSnapshot> watch(String greenhouseId) => _alerts(greenhouseId)
      .orderBy('createdAt', descending: true)
      .limit(limite)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => AlertsSnapshot(
            alerts: [
              for (final doc in snap.docs)
                AlertAdapter.fromFirestore(doc.id, doc.data()),
            ],
            fromCache: snap.metadata.isFromCache,
          ));

  @override
  Future<void> attend(String greenhouseId, String alertId, String uid) =>
      _alerts(greenhouseId).doc(alertId).update(
          AlertAdapter.attendPatch(uid, FieldValue.serverTimestamp()));
}
