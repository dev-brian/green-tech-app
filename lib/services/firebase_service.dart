/// Servicio de autenticación.
///
/// Por ahora simula login/registro localmente para que puedas avanzar
/// con toda la app sin depender de Firebase todavía.
///
/// Cuando estés listo para conectar Firebase real:
/// 1. `flutterfire configure` en tu proyecto
/// 2. Descomenta firebase_core / firebase_auth en pubspec.yaml
/// 3. Reemplaza los cuerpos de estos métodos por llamadas a FirebaseAuth.instance
class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  String? _currentUserEmail;
  String? get currentUserEmail => _currentUserEmail;
  bool get isLoggedIn => _currentUserEmail != null;

  Future<void> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email y contraseña son obligatorios');
    }
    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }
    // TODO: await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    _currentUserEmail = email;
  }

  Future<void> signUp({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email y contraseña son obligatorios');
    }
    if (password.length < 6) {
      throw Exception('La contraseña debe tener al menos 6 caracteres');
    }
    // TODO: await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    _currentUserEmail = email;
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // TODO: await FirebaseAuth.instance.signOut();
    _currentUserEmail = null;
  }
}
