import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/actuator_model.dart';
import '../models/sensor_model.dart';

/// Una emisión del stream de telemetría.
///
/// [reading] es null cuando el documento del sensor todavía no existe
/// (el simulador / ESP32 aún no ha escrito nada). [fromCache] indica que
/// el dato viene de la caché local de Firestore y no del servidor, lo que
/// usamos para mostrar el aviso de "sin conexión".
class TelemetrySnapshot {
  final SensorReading? reading;
  final bool fromCache;

  const TelemetrySnapshot({required this.reading, required this.fromCache});
}

/// Fuente de lecturas en tiempo real de los sensores.
///
/// La app solo LEE: quien escribe en `telemetria/` es el proyecto
/// simulador (o el ESP32 en el futuro). Ver docs/firestore-contract.md.
abstract class TelemetryRepository {
  Stream<TelemetrySnapshot> watchReading(String sensorId);

  /// Equipos asociados al sensor, ordenados por nombre (HU-M03).
  Stream<List<Actuador>> watchActuators(String sensorId);
}

class FirestoreTelemetryRepository implements TelemetryRepository {
  static const String collection = 'telemetria';
  static const String actuatorsCollection = 'actuadores';

  FirestoreTelemetryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  // Perezoso: no toca Firebase hasta que realmente se usa.
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Stream<TelemetrySnapshot> watchReading(String sensorId) {
    return _db
        .collection(collection)
        .doc(sensorId)
        .snapshots(includeMetadataChanges: true)
        .map((doc) {
      final data = doc.data();
      return TelemetrySnapshot(
        reading: data == null ? null : SensorReading.fromFirestore(doc.id, data),
        fromCache: doc.metadata.isFromCache,
      );
    });
  }

  @override
  Stream<List<Actuador>> watchActuators(String sensorId) {
    return _db
        .collection(actuatorsCollection)
        .where('sensor_id', isEqualTo: sensorId)
        .snapshots()
        .map((query) {
      final lista = query.docs
          .map((d) => Actuador.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
      return lista;
    });
  }
}
