import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../repositories/alerts_repository.dart';
import 'app_status.dart';
import 'notification_service.dart';

/// Bandeja de alertas del invernadero seleccionado (Observer: las pantallas
/// escuchan [alerts] con ValueListenableBuilder).
///
/// Las alertas las crea SOLO el backend; aquí se leen de
/// `greenhouses/{id}/alerts` y lo único que se escribe es "Atender".
class AlertsController {
  AlertsController._internal({
    AlertsRepository? repository,
    bool Function(HydroVariable)? notifEnabled,
    void Function(AlertItem)? notify,
    bool Function()? pushLaCubre,
  })  : _repository = repository ?? FirestoreAlertsRepository(),
        _notifEnabled = notifEnabled,
        _pushLaCubre = pushLaCubre,
        _notify = notify ?? NotificationService.instance.showAlert;

  static final AlertsController instance = AlertsController._internal();

  @visibleForTesting
  factory AlertsController.forTesting(
    AlertsRepository repository, {
    bool Function(HydroVariable)? notifEnabled,
    void Function(AlertItem)? notify,
    bool Function()? pushLaCubre,
  }) =>
      AlertsController._internal(
          repository: repository,
          notifEnabled: notifEnabled,
          notify: notify,
          pushLaCubre: pushLaCubre);

  AlertsRepository _repository;
  bool Function(HydroVariable)? _notifEnabled;
  final void Function(AlertItem) _notify;

  /// true cuando el push de FCM ya avisa esta alerta: la app está en segundo
  /// plano y Android muestra el push solo. Así no salen dos notificaciones
  /// de la misma alerta (la del push y la local de la bandeja).
  bool Function()? _pushLaCubre;

  final ValueNotifier<List<AlertItem>> alerts = ValueNotifier(const []);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  /// Alertas abiertas (`new`): el número del globo en la barra inferior.
  int get activas => alerts.value.where((a) => a.activa).length;

  StreamSubscription<AlertsSnapshot>? _sub;
  String? _greenhouseId;

  /// true si la bandeja ya escucha [greenhouseId] en vivo: entonces ella
  /// misma avisa la alerta y el push en primer plano no se repite.
  bool escucha(String? greenhouseId) =>
      _sub != null && greenhouseId != null && greenhouseId == _greenhouseId;

  /// Nivel con el que ya se avisó cada alerta abierta. Sirve para notificar
  /// solo lo nuevo (o lo que empeoró de aviso a crítica).
  final Map<String, EstadoNivel> _avisadas = {};
  bool _primeraCarga = true;

  /// Atenciones hechas en este celular que Firestore aún no confirma (sin
  /// red se quedan en cola): se muestran ya como atendidas.
  final Map<String, AlertItem> _pendientes = {};

  void configure({
    AlertsRepository? repository,
    bool Function(HydroVariable)? notifEnabled,
    bool Function()? pushLaCubre,
  }) {
    if (repository != null) _repository = repository;
    if (notifEnabled != null) _notifEnabled = notifEnabled;
    if (pushLaCubre != null) _pushLaCubre = pushLaCubre;
  }

  Future<void> start(String greenhouseId) async {
    await stop();
    _greenhouseId = greenhouseId;
    alerts.value = const [];
    error.value = null;
    _avisadas.clear();
    _pendientes.clear();
    _primeraCarga = true;
    if (_repository is FirestoreAlertsRepository && !firebaseReady) {
      error.value = 'Firebase no está configurado en este dispositivo';
      return;
    }
    loading.value = true;
    _sub = _repository.watch(greenhouseId).listen(
      _onSnapshot,
      onError: (Object e) {
        loading.value = false;
        error.value = 'No se pudieron leer las alertas: $e';
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    loading.value = false;
  }

  void _onSnapshot(AlertsSnapshot snap) {
    loading.value = false;
    error.value = null;
    // Lo que el servidor ya marca como atendido deja de estar pendiente.
    _pendientes.removeWhere(
        (id, _) => snap.alerts.any((a) => a.id == id && !a.activa));
    alerts.value = [
      for (final a in snap.alerts) _pendientes[a.id] ?? a,
    ];
    _notificarNuevas(snap.alerts);
  }

  void _notificarNuevas(List<AlertItem> lista) {
    final abiertas = lista.where((a) => a.activa);
    final avisaElPush = _pushLaCubre?.call() ?? false;
    if (_primeraCarga) {
      // Lo que ya estaba abierto al entrar no se notifica: la bandeja lo
      // muestra. Solo avisa lo que llegue de aquí en adelante.
      _primeraCarga = false;
      for (final a in abiertas) {
        _avisadas[a.id] = a.nivel;
      }
      return;
    }
    for (final a in abiertas) {
      final antes = _avisadas[a.id];
      _avisadas[a.id] = a.nivel;
      final empeoro =
          antes == EstadoNivel.alerta && a.nivel == EstadoNivel.critico;
      if ((antes == null || empeoro) &&
          !avisaElPush &&
          a.nivel == EstadoNivel.critico &&
          (a.variable == null || (_notifEnabled?.call(a.variable!) ?? true))) {
        _notify(a);
      }
    }
    _avisadas.removeWhere((id, _) => !abiertas.any((a) => a.id == id));
  }

  /// Marca [alert] como atendida por [uid]. Se ve atendida al instante; si
  /// no hay señal, Firestore guarda el cambio y lo sube al reconectar.
  /// Devuelve false si el servidor lo rechazó.
  Future<bool> attend(AlertItem alert, String uid) async {
    final gh = _greenhouseId;
    if (gh == null || !alert.activa) return false;
    final atendida = alert.atendidaPor(uid, DateTime.now());
    _pendientes[alert.id] = atendida;
    alerts.value = [
      for (final a in alerts.value) a.id == alert.id ? atendida : a,
    ];
    try {
      await _repository.attend(gh, alert.id, uid);
      return true;
    } catch (e) {
      _pendientes.remove(alert.id);
      alerts.value = [
        for (final a in alerts.value) a.id == alert.id ? alert : a,
      ];
      error.value = 'No se pudo atender la alerta: $e';
      return false;
    }
  }
}
