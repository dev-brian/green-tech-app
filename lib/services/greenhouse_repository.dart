import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/greenhouse.dart';

/// Error de negocio al buscar o unirse a un invernadero, con un mensaje
/// listo para mostrar.
class GreenhouseException implements Exception {
  final String message;
  const GreenhouseException(this.message);

  @override
  String toString() => message;
}

/// Acceso a los invernaderos del usuario. Mismo modelo que la PWA
/// (green-tech `docs/contrato-datos.md`, sección 1).
abstract class GreenhouseRepository {
  /// Invernaderos donde `memberIds` contiene a [uid], con el rol de
  /// `members/{uid}`. Ordenados por nombre.
  Future<List<Greenhouse>> fetchForUser(String uid);

  /// Une al usuario como `operador` con un código de invitación.
  /// Devuelve el id del invernadero.
  Future<String> joinByCode({
    required String uid,
    required String code,
    String? email,
    String? name,
  });
}

class FirestoreGreenhouseRepository implements GreenhouseRepository {
  FirestoreGreenhouseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Greenhouse>> fetchForUser(String uid) async {
    // Sin red, Firestore responde desde su caché local: el productor
    // puede abrir la app en campo con el último invernadero conocido.
    final snap = await _db
        .collection('greenhouses')
        .where('memberIds', arrayContains: uid)
        .get();

    final result = await Future.wait(snap.docs.map((doc) async {
      var role = GreenhouseRole.operador;
      try {
        final member = await doc.reference.collection('members').doc(uid).get();
        role = GreenhouseRole.parse(member.data()?['role']);
      } catch (_) {
        // Sin permiso o sin red: se queda como operador (el rol más bajo).
      }
      final name = doc.data()['name'];
      return Greenhouse(
        id: doc.id,
        name: name is String && name.trim().isNotEmpty ? name : 'Invernadero',
        role: role,
      );
    }));
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  @override
  Future<String> joinByCode({
    required String uid,
    required String code,
    String? email,
    String? name,
  }) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      throw const GreenhouseException('Escribe el código de invitación');
    }

    // Las reglas solo dejan leer un invernadero a sus miembros, así que el
    // código se resuelve con `greenhouse_invites/{código}` (igual que la PWA).
    final DocumentSnapshot<Map<String, dynamic>> invite;
    try {
      invite = await _db.collection('greenhouse_invites').doc(clean).get();
    } on FirebaseException catch (e) {
      throw GreenhouseException(_message(e));
    }
    final greenhouseId = invite.data()?['greenhouseId'];
    if (!invite.exists || greenhouseId is! String || greenhouseId.isEmpty) {
      throw const GreenhouseException(
          'Código no válido. Pídele a tu administrador un código nuevo');
    }

    final ghRef = _db.collection('greenhouses').doc(greenhouseId);
    final batch = _db.batch()
      ..update(ghRef, {
        'memberIds': FieldValue.arrayUnion([uid]),
      })
      ..set(ghRef.collection('members').doc(uid), {
        'role': 'operador',
        'email': email ?? '',
        'name': name ?? (email ?? 'Usuario'),
        'joinedAt': DateTime.now().toUtc().toIso8601String(),
        'inviteCode': clean,
      });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw GreenhouseException(_message(e));
    }
    return greenhouseId;
  }

  static String _message(FirebaseException e) => switch (e.code) {
        'permission-denied' =>
          'No se pudo unir: el código ya no es válido o ya eres miembro',
        'unavailable' => 'Sin conexión. Inténtalo cuando tengas internet',
        _ => 'No se pudo unir al invernadero (${e.code})',
      };
}
