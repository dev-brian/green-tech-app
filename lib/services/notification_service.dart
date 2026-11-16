import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/push_alert.dart';
import '../models/sensor_model.dart';

/// Envoltura sobre `flutter_local_notifications`.
///
/// Muestra en el celular las alertas que detecta la bandeja
/// ([showAlert]) y los push de FCM que llegan con la app abierta
/// ([showPush]). Con la app cerrada, Android muestra el push solo en el
/// canal [canalCritico] (ver AndroidManifest.xml).
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  /// Canales de Android. [canalCritico] es también el canal por defecto
  /// de FCM (meta-data en AndroidManifest.xml).
  static const canalCritico = 'greentech_critico';
  static const canalAlerta = 'greentech_alerta';

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
      // Se crean desde el inicio para que un push que llegue con la app
      // cerrada ya tenga su canal con importancia máxima.
      await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(canalCritico, 'Alertas críticas',
              description: 'Notificaciones de estado de cultivo GREEN TECH',
              importance: Importance.max));
      await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(canalAlerta, 'Alertas de cultivo',
              description: 'Notificaciones de estado de cultivo GREEN TECH',
              importance: Importance.high));
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
    final channelId = esCritico ? canalCritico : canalAlerta;
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

  /// Push de FCM recibido con la app abierta.
  Future<void> showPush(PushAlert alert) async {
    if (!_ready) return;
    final androidDetails = AndroidNotificationDetails(
      alert.critica ? canalCritico : canalAlerta,
      alert.critica ? 'Alertas críticas' : 'Alertas de cultivo',
      channelDescription: 'Notificaciones de estado de cultivo GREEN TECH',
      importance: alert.critica ? Importance.max : Importance.high,
      priority: alert.critica ? Priority.max : Priority.high,
    );
    try {
      await _plugin.show(
        alert.notificationId,
        alert.title,
        alert.body,
        NotificationDetails(
            android: androidDetails, iOS: const DarwinNotificationDetails()),
      );
    } catch (e) {
      debugPrint('NotificationService: no se pudo mostrar el push ($e)');
    }
  }
}
