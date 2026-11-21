import 'package:cloud_firestore/cloud_firestore.dart';

/// Tokens de Firebase Cloud Messaging del usuario (esquema 2.6):
/// `users/{uid}/fcmTokens/{tokenId}` con `token`, `platform`, `createdAt` y
/// `lastSeenAt`. Las reglas solo dejan leer y escribir al propio usuario.
abstract class FcmTokenRepository {
  /// Registra [token] (o renueva su `lastSeenAt` si ya existía).
  Future<void> save(String uid, String token, {String platform = 'android'});

  /// Borra [token] para que el backend deje de mandarle push.
  Future<void> remove(String uid, String token);
}

class FirestoreFcmTokenRepository implements FcmTokenRepository {
  FirestoreFcmTokenRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// El propio token es el id del documento: si el celular lo vuelve a
  /// registrar no se duplica, y el backend puede borrarlo directo cuando FCM
  /// responde que ya no es válido.
  DocumentReference<Map<String, dynamic>> ref(String uid, String token) =>
      _db.collection('users').doc(uid).collection('fcmTokens').doc(token);

  @override
  Future<void> save(String uid, String token,
      {String platform = 'android'}) async {
    final doc = ref(uid, token);
    var existe = false;
    try {
      existe = (await doc.get()).exists;
    } catch (_) {
      // Sin red: se escribe igual y Firestore lo sube al reconectar.
    }
    await doc.set({
      'token': token,
      'platform': platform,
      'lastSeenAt': FieldValue.serverTimestamp(),
      if (!existe) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> remove(String uid, String token) => ref(uid, token).delete();
}
