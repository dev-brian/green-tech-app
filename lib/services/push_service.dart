import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/push_alert.dart';
import '../repositories/fcm_token_repository.dart';

/// Lo que la app necesita de Firebase Cloud Messaging. La implementación
/// real envuelve `FirebaseMessaging` (Adapter); en pruebas se usa un falso.
abstract class PushMessaging {
  /// Pide permiso de notificaciones (Android 13+). true si quedó concedido.
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();

  /// Push que llegan con la app abierta (Android no las muestra solo).
  Stream<PushAlert> get onForeground;

  /// El usuario tocó una notificación con la app en segundo plano.
  Stream<PushAlert> get onOpened;

  /// Notificación que abrió la app desde cerrada, si hubo.
  Future<PushAlert?> initialOpened();
}

class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  static PushAlert _alerta(RemoteMessage m) => PushAlert.fromMessage(
        m.data,
        title: m.notification?.title,
        body: m.notification?.body,
      );

  @override
  Future<bool> requestPermission() async {
    final s = await _fm.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  @override
  Future<void> deleteToken() => _fm.deleteToken();

  @override
  Stream<PushAlert> get onForeground =>
      FirebaseMessaging.onMessage.map(_alerta);

  @override
  Stream<PushAlert> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_alerta);

  @override
  Future<PushAlert?> initialOpened() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : _alerta(m);
  }
}

/// Push de alertas críticas (HU-M05, Rodrigo).
///
/// La app NO decide qué es una alerta: el motor del backend crea la alerta
/// en `greenhouses/{id}/alerts` y manda el push a los tokens de los miembros.
/// Aquí solo:
/// 1. Registramos el token del celular en `users/{uid}/fcmTokens` al iniciar
///    sesión (y cuando FCM lo renueva).
/// 2. Lo borramos al cerrar sesión, para que no lleguen alertas de otra cuenta.
/// 3. Con la app abierta mostramos el push como notificación local, salvo
///    que la bandeja ya esté escuchando ese invernadero (ella avisa sola).
/// 4. Al tocar una notificación pedimos abrir la bandeja ([openAlerts]).
class PushService {
  PushService._internal({
    PushMessaging? messaging,
    FcmTokenRepository? tokens,
  })  : _messaging = messaging ?? FirebasePushMessaging(),
        _tokens = tokens ?? FirestoreFcmTokenRepository();

  static final PushService instance = PushService._internal();

  @visibleForTesting
  factory PushService.forTesting(
          PushMessaging messaging, FcmTokenRepository tokens) =>
      PushService._internal(messaging: messaging, tokens: tokens);

  final PushMessaging _messaging;
  final FcmTokenRepository _tokens;

  /// Sube cada vez que el usuario toca una notificación de alerta. El
  /// Dashboard lo escucha y abre la bandeja.
  final ValueNotifier<PushAlert?> openAlerts = ValueNotifier(null);

  /// false si el usuario negó el permiso de notificaciones.
  final ValueNotifier<bool> permitido = ValueNotifier(true);

  String? _uid;
  String? _token;
  String? get token => _token;

  final List<StreamSubscription<dynamic>> _subs = [];
  StreamSubscription<String>? _refreshSub;
  bool _iniciado = false;

  late bool Function(String? greenhouseId) _bandejaEscucha;
  late Future<void> Function(PushAlert) _mostrar;

  /// Arranca el servicio. [uidChanges] emite el uid al iniciar sesión y null
  /// al cerrarla; [bandejaEscucha] dice si AlertsController ya está viendo
  /// ese invernadero; [mostrar] pinta la notificación local.
  Future<void> init({
    required Stream<String?> uidChanges,
    required bool Function(String? greenhouseId) bandejaEscucha,
    required Future<void> Function(PushAlert) mostrar,
  }) async {
    if (_iniciado) return;
    _iniciado = true;
    _bandejaEscucha = bandejaEscucha;
    _mostrar = mostrar;

    _subs.add(_messaging.onForeground.listen(_onForeground));
    _subs.add(_messaging.onOpened.listen((a) => openAlerts.value = a));
    try {
      final inicial = await _messaging.initialOpened();
      if (inicial != null) openAlerts.value = inicial;
    } catch (e) {
      debugPrint('PushService: sin mensaje inicial ($e)');
    }

    _subs.add(uidChanges.listen((uid) async {
      if (uid == null) {
        _uid = null;
        await _refreshSub?.cancel();
        _refreshSub = null;
        return;
      }
      if (uid != _uid) await register(uid);
    }));
  }

  /// Guarda el token de este celular para [uid].
  Future<void> register(String uid) async {
    _uid = uid;
    try {
      permitido.value = await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      await _tokens.save(uid, token);
    } catch (e) {
      // Sin Google Play Services, sin red, etc.: la bandeja sigue
      // funcionando con su aviso local, así que no tumbamos el login.
      debugPrint('PushService: no se pudo registrar el token ($e)');
    }
    await _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((nuevo) async {
      final u = _uid;
      if (u == null) return;
      final viejo = _token;
      _token = nuevo;
      try {
        await _tokens.save(u, nuevo);
        if (viejo != null && viejo != nuevo) await _tokens.remove(u, viejo);
      } catch (e) {
        debugPrint('PushService: no se pudo renovar el token ($e)');
      }
    });
  }

  /// Llamar ANTES de cerrar sesión en Firebase Auth: borrar el token
  /// requiere que el usuario siga autenticado (reglas de Firestore).
  Future<void> unregister() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (uid != null && token != null) {
      try {
        await _tokens.remove(uid, token).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('PushService: no se pudo borrar el token ($e)');
      }
    }
    try {
      // Invalida el token en FCM: aunque el borrado de arriba se quede en
      // cola sin red, el backend recibe "not registered" y lo limpia.
      await _messaging.deleteToken().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('PushService: no se pudo invalidar el token ($e)');
    }
  }

  Future<void> _onForeground(PushAlert alerta) async {
    if (_bandejaEscucha(alerta.greenhouseId)) return;
    await _mostrar(alerta);
  }

  @visibleForTesting
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _refreshSub?.cancel();
    _iniciado = false;
  }
}
