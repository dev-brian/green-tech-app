import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_model.dart';
import 'api_service.dart';
import 'app_status.dart';
import 'notification_service.dart';
import 'telemetry_repository.dart';

/// Fuente única de la lectura "activa" del cultivo.
///
/// Los sensores llegan en tiempo real desde Firestore (`telemetria/`, ver
/// [TelemetryRepository]); la app no simula nada, eso lo hace un proyecto
/// aparte que escribe en la misma colección. Por separado se mantiene el
/// clima de la ubicación elegida (OpenWeather vía [ApiService]) en
/// [weather], que ya no sobrescribe la lectura de los sensores.
/// Dashboard, Detalle de sensor y Alertas leen todos de aquí, así que
/// siempre están sincronizados entre sí.
class SensorDataController {
  SensorDataController._internal({TelemetryRepository? repository})
      : _repository = repository ?? FirestoreTelemetryRepository();
  static final SensorDataController instance =
      SensorDataController._internal();

  /// Instancia aislada para pruebas, con un repositorio falso.
  @visibleForTesting
  factory SensorDataController.forTesting(TelemetryRepository repository) =>
      SensorDataController._internal(repository: repository);

  static const String defaultSensorId = 'ESP32-01';

  final ApiService api = ApiService();
  final TelemetryRepository _repository;

  // --- Sensores (Firestore) ---
  final ValueNotifier<SensorReading?> currentReading = ValueNotifier(null);
  final ValueNotifier<List<AlertItem>> alerts = ValueNotifier(const []);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  // --- Clima de la ubicación (OpenWeather) ---
  final ValueNotifier<SensorReading?> weather = ValueNotifier(null);
  final ValueNotifier<bool> weatherLoading = ValueNotifier(false);
  final ValueNotifier<String?> weatherError = ValueNotifier(null);

  StreamSubscription<TelemetrySnapshot>? _subscription;
  String _sensorId = defaultSensorId;

  bool _notifTemp = true;
  bool _notifHumedadAire = true;
  bool _notifHumedadSuelo = true;
  EstadoNivel? _ultimoEstadoNotificado;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _notifTemp = prefs.getBool('notif_temp') ?? true;
    _notifHumedadAire = prefs.getBool('notif_humedad_aire') ?? true;
    _notifHumedadSuelo = prefs.getBool('notif_humedad_suelo') ?? true;
  }

  bool get notifTemp => _notifTemp;
  bool get notifHumedadAire => _notifHumedadAire;
  bool get notifHumedadSuelo => _notifHumedadSuelo;

  Future<void> setNotifPref(String metric, bool value) async {
    // Actualiza el campo en memoria de inmediato (sincrono) para que la UI
    // (setState en ProfileScreen) refleje el cambio en el mismo frame; la
    // escritura a SharedPreferences puede tardar y va después.
    switch (metric) {
      case 'temp':
        _notifTemp = value;
        break;
      case 'humedad_aire':
        _notifHumedadAire = value;
        break;
      case 'humedad_suelo':
        _notifHumedadSuelo = value;
        break;
    }
    final prefs = await SharedPreferences.getInstance();
    switch (metric) {
      case 'temp':
        await prefs.setBool('notif_temp', value);
        break;
      case 'humedad_aire':
        await prefs.setBool('notif_humedad_aire', value);
        break;
      case 'humedad_suelo':
        await prefs.setBool('notif_humedad_suelo', value);
        break;
    }
  }

  String get currentLocation => api.currentLocation;

  String get sensorId => _sensorId;

  /// Se suscribe en tiempo real al documento `telemetria/{sensorId}`.
  /// Llamarlo de nuevo cancela la suscripción anterior (sirve como
  /// "reintentar" o para cambiar de sensor).
  Future<void> start({String? sensorId}) async {
    _sensorId = sensorId ?? _sensorId;
    await _subscription?.cancel();
    _subscription = null;
    error.value = null;

    if (!firebaseReady) {
      loading.value = false;
      error.value = 'Firebase no está configurado en este dispositivo';
      return;
    }

    loading.value = true;
    _subscription = _repository.watchReading(_sensorId).listen(
      _onSnapshot,
      onError: (Object e) {
        loading.value = false;
        error.value = 'No se pudo leer los sensores: $e';
      },
    );
  }

  void _onSnapshot(TelemetrySnapshot snap) {
    loading.value = false;
    error.value = null;
    final reading = snap.reading;
    // Documento inexistente: dejamos la última lectura conocida (si la
    // hay) y la UI muestra "Esperando datos del sensor".
    if (reading == null) return;
    currentReading.value = reading;
    _refreshAlerts(reading);
  }

  /// Re-suscribe los sensores y recarga el clima de la ubicación.
  Future<void> refresh() async {
    await Future.wait([start(), loadRealWeather()]);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Trae el clima real para [location] (o la ubicación ya seleccionada).
  Future<void> loadRealWeather({String? location}) async {
    weatherLoading.value = true;
    weatherError.value = null;
    if (location != null && location.trim().isNotEmpty) {
      api.setLocation(location.trim());
    }
    try {
      weather.value = await api.getCurrentReading();
    } catch (e) {
      weatherError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      weatherLoading.value = false;
    }
  }

  void _refreshAlerts(SensorReading reading) {
    final nuevas = reading.alertasGeneradas;
    alerts.value = nuevas;

    final estadoGeneral = reading.estadoGeneral;
    // Solo disparamos notificación cuando el estado general CAMBIA
    // respecto al último aviso, para no repetir la misma notificación con
    // cada lectura nueva que llega del stream.
    if (estadoGeneral != EstadoNivel.normal &&
        estadoGeneral != _ultimoEstadoNotificado) {
      for (final alerta in nuevas.where((a) => a.nivel != EstadoNivel.normal)) {
        final prefijo = alerta.id.split('-').first;
        final permitido = switch (prefijo) {
          'temp' => _notifTemp,
          'aire' => _notifHumedadAire,
          'suelo' => _notifHumedadSuelo,
          _ => true,
        };
        if (permitido) {
          NotificationService.instance.showAlert(alerta);
        }
      }
    }
    _ultimoEstadoNotificado = estadoGeneral;
  }
}
