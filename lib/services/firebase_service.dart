import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio de autenticación usando Firebase Auth y Google Sign-In.
class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  String? _currentUserEmail;
  String? get currentUserEmail => _currentUserEmail;
  bool get isLoggedIn => _currentUserEmail != null;

  Future<void> signIn({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email y contraseña son obligatorios');
    }
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      _currentUserEmail = cred.user?.email;
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') msg = 'Usuario no encontrado';
      if (e.code == 'wrong-password') msg = 'Contraseña incorrecta';
      throw Exception(msg + (e.message != null ? ': ${e.message}' : ''));
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email y contraseña son obligatorios');
    }
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      _currentUserEmail = cred.user?.email;
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al registrarse';
      if (e.code == 'weak-password') msg = 'La contraseña es muy débil';
      if (e.code == 'email-already-in-use') msg = 'El email ya está en uso';
      if (e.code == 'invalid-email') msg = 'Email inválido';
      throw Exception(msg + (e.message != null ? ': ${e.message}' : ''));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Inicio de sesión con Google cancelado');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      _currentUserEmail = userCred.user?.email;
    } on FirebaseAuthException catch (e) {
      throw Exception('Error en Google Sign-In: ${e.message ?? e.code}');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    _currentUserEmail = null;
  }
}
