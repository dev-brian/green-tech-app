import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/sensor_model.dart';

/// Envoltura sobre `flutter_local_notifications`.
///
/// No depende de Firebase ni de un backend: sirve para mostrar
/// notificaciones reales en el dispositivo mientras no haya IoT ni FCM
/// conectados. Cuando conectes Firebase Cloud Messaging más adelante,
/// esto puede seguir usándose para notificaciones locales/en primer
/// plano sin cambios grandes.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await _plugin.initialize(settings);
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      // No tumbamos la app si el dispositivo/emulador no soporta
      // notificaciones (o el usuario las bloqueó): solo lo dejamos
      // registrado para depuración.
      debugPrint('NotificationService: no se pudo inicializar ($e)');
    }
  }

  Future<void> showAlert(AlertItem alert) async {
    if (!_ready) return;

    final esCritico = alert.nivel == EstadoNivel.critico;
    final channelId = esCritico ? 'greentech_critico' : 'greentech_alerta';
    final channelName = esCritico ? 'Alertas críticas' : 'Alertas de cultivo';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notificaciones de estado de cultivo GREEN TECH',
      importance: esCritico ? Importance.max : Importance.high,
      priority: esCritico ? Priority.max : Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.show(
        alert.id.hashCode,
        esCritico ? '⚠️ Alerta crítica de cultivo' : 'Atención en tu cultivo',
        alert.mensaje,
        details,
      );
    } catch (e) {
      debugPrint('NotificationService: no se pudo mostrar la alerta ($e)');
    }
  }
}
