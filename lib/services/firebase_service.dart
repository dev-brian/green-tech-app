import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'session_storage.dart';

/// Error de autenticación con un mensaje listo para mostrar al usuario.
class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException(this.code, this.message);

  @override
  String toString() => message;
}

/// Servicio de autenticación sobre Firebase Auth (HU-M01).
///
/// Centraliza login, registro, recuperación de contraseña y cierre de sesión
/// para que las pantallas no dependan directamente de `FirebaseAuth`.
class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  // Getter perezoso: no toca Firebase hasta que realmente se usa
  // (permite construir pantallas en tests sin inicializar Firebase).
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUserEmail => _auth.currentUser?.email;
  bool get isLoggedIn => _auth.currentUser != null;

  /// Emite el usuario actual cada vez que cambia el estado de sesión.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Configura la persistencia local de la sesión.
  /// En Android/iOS Firebase ya persiste la sesión por defecto;
  /// en web hay que pedirlo explícitamente.
  Future<void> init() async {
    if (kIsWeb) await _auth.setPersistence(Persistence.LOCAL);
  }

  /// Espera a que Firebase restaure la sesión guardada en el dispositivo
  /// y devuelve el usuario (o null si no hay sesión activa).
  Future<User?> restoreSession(
      {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final user = await _auth.authStateChanges().first.timeout(timeout);
      if (user == null) return null;
      // Verifica que la cuenta siga vigente (p. ej. no fue deshabilitada).
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-disabled' || e.code == 'user-not-found' ||
            e.code == 'user-token-expired') {
          await _auth.signOut();
          return null;
        }
        // Sin red u otro error transitorio: conservamos la sesión local.
      }
      return _auth.currentUser;
    } on TimeoutException {
      return _auth.currentUser;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _validateCredentials(email, password);
    await _guard(() => _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password));
    await SessionStorage.saveLastEmail(email);
  }

  Future<void> signUp({required String email, required String password}) async {
    _validateCredentials(email, password);
    await _guard(() => _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password));
    await SessionStorage.saveLastEmail(email);
  }

  /// Envía el correo de restablecimiento de contraseña.
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (email.trim().isEmpty) {
      throw const AuthException('missing-email', 'Ingresa tu email');
    }
    await _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  Future<void> signOut() => _guard(() => _auth.signOut());

  void _validateCredentials(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const AuthException(
          'missing-fields', 'Email y contraseña son obligatorios');
    }
    if (password.length < 6) {
      throw const AuthException(
          'weak-password', 'La contraseña debe tener al menos 6 caracteres');
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, messageForCode(e.code));
    }
  }

  /// Traduce los códigos de Firebase Auth a mensajes en español.
  static String messageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El formato del email no es válido';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email o contraseña incorrectos';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este email';
      case 'weak-password':
        return 'La contraseña es demasiado débil (mínimo 6 caracteres)';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet e inténtalo de nuevo';
      case 'operation-not-allowed':
        return 'El inicio de sesión con email no está habilitado en Firebase';
      default:
        return 'Ocurrió un error inesperado ($code)';
    }
  }
}
