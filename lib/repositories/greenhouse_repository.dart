import 'package:cloud_firestore/cloud_firestore.dart';

import '../adapters/greenhouse_adapter.dart';
import '../models/greenhouse.dart';

/// Error con un mensaje listo para mostrar al usuario.
class GreenhouseException implements Exception {
  final String message;
  const GreenhouseException(this.message);

  @override
  String toString() => message;
}

/// Invernaderos a los que pertenece el usuario.
///
/// La app solo puede LISTARLOS y UNIRSE con un código de invitación (lo
/// mismo que hace un operador en la PWA). Crear invernaderos, cambiar
/// umbrales o gestionar miembros se hace solo en la PWA.
abstract class GreenhouseRepository {
  Future<List<Greenhouse>> myGreenhouses(String uid);

  /// Une al usuario como `operador` y devuelve el id del invernadero.
  Future<String> joinWithCode({
    required String code,
    required String uid,
    String? email,
    String? name,
  });

  /// Saca al usuario del invernadero: lo quita de `memberIds` y borra
  /// `members/{uid}` en un solo batch (las reglas exigen ambos juntos).
  Future<void> leave({required String greenhouseId, required String uid});
}

class FirestoreGreenhouseRepository implements GreenhouseRepository {
  FirestoreGreenhouseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _greenhouses =>
      _db.collection('greenhouses');

  @override
  Future<List<Greenhouse>> myGreenhouses(String uid) async {
    // Sin red, Firestore responde con lo que tenga en caché.
    final snap =
        await _greenhouses.where('memberIds', arrayContains: uid).get();
    final list = await Future.wait(snap.docs.map((doc) async {
      Map<String, dynamic>? member;
      try {
        member =
            (await doc.reference.collection('members').doc(uid).get()).data();
      } catch (_) {
        // Sin rol legible el invernadero se muestra igual.
      }
      return GreenhouseAdapter.fromFirestore(doc.id, doc.data(),
          member: member);
    }));
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Mismo flujo que `joinWorkspaceByCode` de la PWA: resuelve el código en
  /// `greenhouse_invites/{code}` y, en un solo batch, agrega el uid a
  /// `memberIds` y crea `members/{uid}` con rol `operador` y el código (las
  /// reglas lo exigen).
  @override
  Future<String> joinWithCode({
    required String code,
    required String uid,
    String? email,
    String? name,
  }) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      throw const GreenhouseException('Escribe el código de invitación');
    }

    try {
      String? greenhouseId;
      final invite =
          await _db.collection('greenhouse_invites').doc(clean).get();
      if (invite.exists) {
        greenhouseId = invite.data()?['greenhouseId'] as String?;
      }
      if (greenhouseId == null || greenhouseId.isEmpty) {
        throw const GreenhouseException(
            'Ese código no existe. Pídele uno nuevo al administrador en la PWA');
      }

      final ghRef = _greenhouses.doc(greenhouseId);
      final batch = _db.batch()
        ..update(ghRef, {
          'memberIds': FieldValue.arrayUnion([uid]),
        })
        ..set(ghRef.collection('members').doc(uid), {
          'role': 'operador',
          'email': email,
          'name': name,
          'joinedAt': DateTime.now().toUtc().toIso8601String(),
          'inviteCode': clean,
        });
      await batch.commit();
      return greenhouseId;
    } on GreenhouseException {
      rethrow;
    } on FirebaseException catch (e) {
      throw GreenhouseException(switch (e.code) {
        'permission-denied' =>
          'El código no es válido o ya eres miembro de ese invernadero',
        'unavailable' => 'Sin conexión. Necesitas internet para unirte',
        _ => 'No se pudo unir al invernadero (${e.code})',
      });
    }
  }

  @override
  Future<void> leave({
    required String greenhouseId,
    required String uid,
  }) async {
    final ghRef = _greenhouses.doc(greenhouseId);
    final batch = _db.batch()
      ..update(ghRef, {
        'memberIds': FieldValue.arrayRemove([uid]),
      })
      ..delete(ghRef.collection('members').doc(uid));
    await batch.commit();
  }
}
