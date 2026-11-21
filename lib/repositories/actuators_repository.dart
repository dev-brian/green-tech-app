import 'package:cloud_firestore/cloud_firestore.dart';

import '../adapters/actuator_adapter.dart';
import '../models/actuator_state.dart';

/// Estado de los actuadores de una zona, solo lectura.
abstract class ActuatorsRepository {
  /// Emite null mientras el backend no haya escrito el documento.
  Stream<ZoneActuators?> watch(String greenhouseId, String zoneId);
}

class FirestoreActuatorsRepository implements ActuatorsRepository {
  FirestoreActuatorsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Stream<ZoneActuators?> watch(String greenhouseId, String zoneId) => _db
      .collection('greenhouses')
      .doc(greenhouseId)
      .collection('actuators')
      .doc(zoneId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        return data == null ? null : ActuatorAdapter.fromFirestore(zoneId, data);
      });
}
