import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Datos de la sesión guardados de forma segura en el dispositivo.
class StoredSession {
  final String uid;
  final String? email;
  final String idToken;
  final DateTime? expiresAt;

  const StoredSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.expiresAt,
  });

  bool get isExpired =>
      expiresAt == null || DateTime.now().isAfter(expiresAt!);
}

/// Almacena los tokens de sesión cifrados (HU-M01 / Task 1.3).
///
/// Usa `flutter_secure_storage`:
///  - Android: datos cifrados con una llave guardada en Android Keystore.
///  - iOS: Keychain.
///
/// Nunca se guarda la contraseña del usuario. El refresh token lo administra
/// el SDK de Firebase Auth; aquí guardamos el ID token vigente (JWT), su
/// expiración y el uid, para poder enviarlo a nuestra API/backend y para
/// saber si hay una sesión válida sin depender de SharedPreferences.
class SecureTokenStorage {
  SecureTokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _kUid = 'auth_uid';
  static const _kEmail = 'auth_email';
  static const _kIdToken = 'auth_id_token';
  static const _kExpiresAt = 'auth_id_token_expires_at';

  static Future<void> save({
    required String uid,
    required String? email,
    required String idToken,
    required DateTime? expiresAt,
  }) async {
    await _storage.write(key: _kUid, value: uid);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kIdToken, value: idToken);
    await _storage.write(
        key: _kExpiresAt, value: expiresAt?.toUtc().toIso8601String());
  }

  static Future<StoredSession?> read() async {
    try {
      final values = await _storage.readAll();
      final uid = values[_kUid];
      final token = values[_kIdToken];
      if (uid == null || token == null) return null;
      final exp = values[_kExpiresAt];
      return StoredSession(
        uid: uid,
        email: values[_kEmail],
        idToken: token,
        expiresAt: exp == null ? null : DateTime.tryParse(exp)?.toLocal(),
      );
    } catch (_) {
      // Datos corruptos (p. ej. tras restaurar un respaldo): se descartan.
      await clear();
      return null;
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kUid);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kExpiresAt);
  }
}
