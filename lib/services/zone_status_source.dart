import 'package:cloud_firestore/cloud_firestore.dart';

import '../adapters/zone_status_adapter.dart';
import '../models/zone_status.dart';

/// Una emisión del estado del invernadero.
///
/// [zones] queda vacío cuando el documento todavía no existe (el backend
/// aún no ha escrito nada). [fromCache] indica que el dato viene de la
/// caché local de Firestore y no del servidor, lo que usamos para mostrar
/// el aviso de "sin conexión".
class ZoneStatusSnapshot {
  final Map<String, ZoneStatus> zones;
  final bool fromCache;

  const ZoneStatusSnapshot({required this.zones, required this.fromCache});
}

/// Fuente del estado en tiempo real de las zonas de un invernadero.
///
/// Hay dos implementaciones con esta misma interfaz:
/// [FirestoreZoneStatusSource] (datos reales) y `MockZoneStatusSource`
/// (datos de prueba). El resto de la app no sabe cuál está usando.
abstract class ZoneStatusSource {
  /// true si necesita que Firebase esté inicializado para funcionar.
  bool get requiresFirebase;

  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId);
}

/// Lee `greenhouses/{greenhouseId}/state/latest`. La app solo LEE: quien
/// escribe (y calcula los niveles) es el backend.
class FirestoreZoneStatusSource implements ZoneStatusSource {
  FirestoreZoneStatusSource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  // Perezoso: no toca Firebase hasta que realmente se usa.
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  bool get requiresFirebase => true;

  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) {
    return _db
        .collection('greenhouses')
        .doc(greenhouseId)
        .collection('state')
        .doc('latest')
        .snapshots(includeMetadataChanges: true)
        .map((doc) {
      final data = doc.data();
      return ZoneStatusSnapshot(
        zones: data == null ? const {} : ZoneStatusAdapter.zonesFromDocument(data),
        fromCache: doc.metadata.isFromCache,
      );
    });
  }
}
