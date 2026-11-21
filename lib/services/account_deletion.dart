import '../models/greenhouse.dart';
import '../repositories/greenhouse_repository.dart';

/// Error al borrar la cuenta, con un mensaje listo para mostrar.
class AccountDeletionException implements Exception {
  final String code;
  final String message;
  const AccountDeletionException(this.code, this.message);

  @override
  String toString() => message;
}

/// Borra la cuenta del usuario y sus datos en la nube (checklist de servicios
/// en la nube 02 y 18: borrado de cuenta y datos personales).
///
/// Qué se borra:
/// 1. Su token de push (`users/{uid}/fcmTokens/{token}`).
/// 2. Su membresía en cada invernadero (`memberIds` y `members/{uid}`).
/// 3. Su cuenta de Firebase Authentication.
/// 4. Lo guardado en el teléfono (token cifrado, último correo, foto).
///
/// Las lecturas y alertas son del invernadero, no del usuario, así que se
/// quedan. Un administrador no puede borrarse desde la app: dejaría el
/// invernadero sin quien lo gestione; primero debe ceder o borrar el
/// invernadero en la PWA.
///
/// Las dependencias se inyectan para poder probar el orden sin Firebase.
class AccountDeletion {
  AccountDeletion({
    required this.uid,
    required this.greenhouses,
    required this.secondsSinceSignIn,
    required this.unregisterPush,
    required this.deleteAuthUser,
    required this.clearLocalData,
  });

  final String uid;
  final GreenhouseRepository greenhouses;

  /// Segundos desde el último inicio de sesión. Firebase pide una sesión
  /// reciente (unos 5 min) para borrar una cuenta.
  final Future<int> Function() secondsSinceSignIn;
  final Future<void> Function() unregisterPush;
  final Future<void> Function() deleteAuthUser;
  final Future<void> Function() clearLocalData;

  static const int maxSecondsSinceSignIn = 5 * 60;

  Future<void> run() async {
    // Se valida todo ANTES de borrar algo, para no dejar la cuenta a medias.
    if (await secondsSinceSignIn() > maxSecondsSinceSignIn) {
      throw const AccountDeletionException(
        'requires-recent-login',
        'Por seguridad, cierra sesión, vuelve a entrar y después borra tu cuenta.',
      );
    }

    final List<Greenhouse> mios = await greenhouses.myGreenhouses(uid);
    final administrados =
        mios.where((g) => g.role == GreenhouseRole.admin).toList();
    if (administrados.isNotEmpty) {
      final nombres = administrados.map((g) => g.name).join(', ');
      throw AccountDeletionException(
        'is-admin',
        'Eres administrador de $nombres. Cede la administración o borra el '
            'invernadero en la PWA antes de borrar tu cuenta.',
      );
    }

    // El token de push y la membresía se borran con la sesión aún activa:
    // las reglas exigen que el dueño sea quien los borre.
    await unregisterPush();
    for (final g in mios) {
      await greenhouses.leave(greenhouseId: g.id, uid: uid);
    }
    await deleteAuthUser();
    await clearLocalData();
  }
}
