import 'package:shared_preferences/shared_preferences.dart';

/// Datos de sesión no sensibles guardados en el dispositivo (HU-M01 / Task 1.3).
///
/// El token de Firebase Auth lo persiste el propio SDK de forma segura
/// (Keychain en iOS, almacenamiento cifrado en Android). Aquí solo guardamos
/// conveniencias como el último email usado para prellenar el login.
/// Nunca se guarda la contraseña.
class SessionStorage {
  SessionStorage._();

  static const _kLastEmail = 'last_login_email';

  static Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastEmail);
  }

  static Future<void> saveLastEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastEmail, email.trim());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastEmail);
  }
}
