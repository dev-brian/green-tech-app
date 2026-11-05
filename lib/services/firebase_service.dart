import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'app_status.dart';
import 'secure_token_storage.dart';
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

  // Si Firebase no se inicializó (ver main.dart), nada toca FirebaseAuth
  // y la app sigue funcionando en modo local.
  User? get currentUser => firebaseReady ? _auth.currentUser : null;
  String? get currentUserEmail => currentUser?.email;
  bool get isLoggedIn => currentUser != null;

  /// Emite el usuario actual cada vez que cambia el estado de sesión.
  Stream<User?> authStateChanges() =>
      firebaseReady ? _auth.authStateChanges() : Stream.value(null);

  void _ensureReady() {
    if (!firebaseReady) {
      throw const AuthException('firebase-not-ready',
          'Firebase no está disponible. Usa "Continuar sin cuenta"');
    }
  }

  /// Configura la persistencia local de la sesión.
  /// En Android/iOS Firebase ya persiste la sesión por defecto;
  /// en web hay que pedirlo explícitamente.
  Future<void> init() async {
    if (kIsWeb) await _auth.setPersistence(Persistence.LOCAL);

    // Cada vez que Firebase emite o renueva el ID token (login, refresh
    // automático ~cada hora, logout) lo reflejamos en el almacenamiento seguro.
    _tokenSub ??= _auth.idTokenChanges().listen((user) async {
      try {
        if (user == null) {
          await SecureTokenStorage.clear();
        } else {
          await _persistToken(user);
        }
      } catch (_) {
        // No bloquear la app por un fallo del almacenamiento seguro.
      }
    });
  }

  StreamSubscription<User?>? _tokenSub;

  /// Guarda el ID token vigente del usuario en almacenamiento cifrado.
  Future<void> _persistToken(User user, {bool forceRefresh = false}) async {
    final result = await user.getIdTokenResult(forceRefresh);
    final token = result.token;
    if (token == null) return;
    await SecureTokenStorage.save(
      uid: user.uid,
      email: user.email,
      idToken: token,
      expiresAt: result.expirationTime,
    );
  }

  /// Devuelve un ID token válido para llamar a la API propia
  /// (header `Authorization: Bearer <token>`). Lo renueva si ya expiró.
  Future<String?> getValidIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final stored = await SecureTokenStorage.read();
    if (stored != null && stored.uid == user.uid && !stored.isExpired) {
      return stored.idToken;
    }
    await _persistToken(user, forceRefresh: true);
    return (await SecureTokenStorage.read())?.idToken;
  }

  /// Espera a que Firebase restaure la sesión guardada en el dispositivo
  /// y devuelve el usuario (o null si no hay sesión activa).
  Future<User?> restoreSession(
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (!firebaseReady) return null;
    try {
      final user = await _auth.authStateChanges().first.timeout(timeout);
      if (user == null) return null;
      // Verifica que la cuenta siga vigente (p. ej. no fue deshabilitada).
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-disabled' || e.code == 'user-not-found' ||
            e.code == 'user-token-expired') {
          await signOut();
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
    _ensureReady();
    _validateCredentials(email, password);
    final cred = await _guard(() => _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password));
    await _afterAuth(cred.user, email);
  }

  Future<void> signUp({required String email, required String password}) async {
    _ensureReady();
    _validateCredentials(email, password);
    final cred = await _guard(() => _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password));
    await _afterAuth(cred.user, email);
  }

  /// Envía el correo de restablecimiento de contraseña.
  Future<void> sendPasswordResetEmail({required String email}) async {
    _ensureReady();
    if (email.trim().isEmpty) {
      throw const AuthException('missing-email', 'Ingresa tu email');
    }
    await _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  /// Client ID "Web" (client_type 3) del proyecto green-tech-96bb2.
  /// Google lo usa para emitir el ID token que luego validamos con Firebase.
  static const _googleServerClientId =
      '998092953685-e9jsneafi6g2tqilh5oofgoh6b4foor0.apps.googleusercontent.com';

  bool _googleReady = false;

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance
        .initialize(serverClientId: _googleServerClientId);
    _googleReady = true;
  }

  /// Inicia sesión con una cuenta de Google.
  /// Devuelve `false` si el usuario cerró el selector de cuentas.
  Future<bool> signInWithGoogle() async {
    _ensureReady();
    final GoogleSignInAccount account;
    try {
      await _initGoogle();
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthException('google-${e.code.name}',
          'No se pudo iniciar sesión con Google. Inténtalo de nuevo');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
          'google-no-token', 'Google no devolvió credenciales. Inténtalo de nuevo');
    }

    final cred = await _guard(() => _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken)));
    await _afterAuth(cred.user, account.email);
    return true;
  }

  /// Guarda el token cifrado y el último email usado tras un login/registro.
  Future<void> _afterAuth(User? user, String email) async {
    if (user != null) {
      try {
        await _persistToken(user);
      } catch (_) {/* el listener de idTokenChanges reintentará */}
    }
    await SessionStorage.saveLastEmail(email);
  }

  /// Cierra sesión y borra los tokens guardados en el dispositivo.
  Future<void> signOut() async {
    if (!firebaseReady) return;
    await _guard(() => _auth.signOut());
    await SecureTokenStorage.clear();
    // Cierra también la cuenta de Google para que la próxima vez
    // se pueda elegir otra cuenta.
    if (!kIsWeb) {
      try {
        await _initGoogle();
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

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
        return 'Este método de inicio de sesión no está habilitado en Firebase';
      case 'account-exists-with-different-credential':
        return 'Ese email ya está registrado con otro método. Entra con email y contraseña';
      default:
        return 'Ocurrió un error inesperado ($code)';
    }
  }
}
