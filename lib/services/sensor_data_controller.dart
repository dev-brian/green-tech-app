import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Fuente única de la lectura "activa" del cultivo.
///
/// Mientras no haya sensores ESP32 reales conectados, la lectura se arma
/// así: se toma el clima real de la ubicación elegida (vía [ApiService])
/// como base, y sobre esa base se pueden aplicar overrides manuales
/// (los sliders del Dashboard) para simular lo que un sensor real
/// reportaría. Dashboard, Detalle de sensor y Alertas leen todos de aquí,
/// así que siempre están sincronizados entre sí — ya no cada pantalla
/// calcula su propio estado por separado.
class SensorDataController {
  SensorDataController._internal();
  static final SensorDataController instance =
      SensorDataController._internal();

  final ApiService api = ApiService();

  final ValueNotifier<SensorReading?> currentReading = ValueNotifier(null);
  final ValueNotifier<List<AlertItem>> alerts = ValueNotifier(const []);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  SensorReading? _baseline; // última lectura real de clima, sin overrides
  double? _overrideTemp;
  double? _overrideHumedadAire;
  double? _overrideHumedadSuelo;

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

  bool get isSimulating =>
      _overrideTemp != null ||
      _overrideHumedadAire != null ||
      _overrideHumedadSuelo != null;

  /// Trae clima real para [location] (o la ubicación ya seleccionada) y lo
  /// usa como nueva base, limpiando cualquier simulación previa.
  Future<void> loadRealWeather({String? location}) async {
    loading.value = true;
    error.value = null;
    if (location != null && location.trim().isNotEmpty) {
      api.setLocation(location.trim());
    }
    try {
      final reading = await api.getCurrentReading();
      _baseline = reading;
      _overrideTemp = null;
      _overrideHumedadAire = null;
      _overrideHumedadSuelo = null;
      _applyCurrentReading();
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading.value = false;
    }
  }

  /// Aplica overrides manuales (sliders del simulador) sobre la última
  /// lectura base real. No vuelve a llamar a la API del clima.
  void setSimulatedValues({
    double? temperatura,
    double? humedadAire,
    double? humedadSuelo,
  }) {
    if (_baseline == null) return;
    if (temperatura != null) _overrideTemp = temperatura;
    if (humedadAire != null) _overrideHumedadAire = humedadAire;
    if (humedadSuelo != null) _overrideHumedadSuelo = humedadSuelo;
    _applyCurrentReading();
  }

  /// Quita los overrides manuales y vuelve a mostrar el clima real base.
  void resetSimulation() {
    _overrideTemp = null;
    _overrideHumedadAire = null;
    _overrideHumedadSuelo = null;
    _applyCurrentReading();
  }

  void _applyCurrentReading() {
    final base = _baseline;
    if (base == null) return;
    final reading = base.copyWith(
      temperatura: _overrideTemp,
      humedadAire: _overrideHumedadAire,
      humedadSuelo: _overrideHumedadSuelo,
      timestamp: DateTime.now(),
    );
    currentReading.value = reading;
    _refreshAlerts(reading);
  }

  void _refreshAlerts(SensorReading reading) {
    final nuevas = reading.alertasGeneradas;
    alerts.value = nuevas;

    final estadoGeneral = reading.estadoGeneral;
    // Solo disparamos notificación cuando el estado general EMPEORA
    // respecto al último aviso, para no saturar con notificaciones
    // repetidas mientras el usuario arrastra un slider.
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
