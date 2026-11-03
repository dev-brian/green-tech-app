import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../adapters/zone_status_adapter.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import 'api_service.dart';
import 'app_status.dart';
import 'mock_zone_status_source.dart';
import 'notification_service.dart';
import 'zone_status_source.dart';

/// Fuente única del estado "activo" del invernadero.
///
/// Las zonas llegan en tiempo real desde un [ZoneStatusSource]: por ahora
/// [MockZoneStatusSource] (datos de prueba); para usar Firestore basta con
/// pasar [FirestoreZoneStatusSource]. Los niveles (semáforo) los calcula el
/// backend; aquí solo se leen. Por separado se mantiene el clima de la
/// ubicación elegida (OpenWeather vía [ApiService]) en [weather].
/// Dashboard, Detalle y Alertas leen todos de aquí, así que siempre están
/// sincronizados entre sí.
class SensorDataController {
  SensorDataController._internal({
    ZoneStatusSource? source,
    this.offlineDelay = const Duration(seconds: 3),
  }) : source = source ?? MockZoneStatusSource();
  static final SensorDataController instance =
      SensorDataController._internal();

  /// Instancia aislada para pruebas, con una fuente falsa.
  @visibleForTesting
  factory SensorDataController.forTesting(
    ZoneStatusSource source, {
    Duration offlineDelay = Duration.zero,
  }) =>
      SensorDataController._internal(
          source: source, offlineDelay: offlineDelay);

  /// Cuánto tiempo seguido deben llegar datos solo de caché antes de
  /// avisar "sin conexión". Al abrir la app Firestore suele emitir primero
  /// la caché y un instante después el servidor; sin este margen el aviso
  /// parpadearía en cada arranque.
  final Duration offlineDelay;

  /// Id de `greenhouses/{id}`, el mismo que usa la web.
  static const String defaultGreenhouseId = 'axtR6p9ocsE0L79H5wbN';

  final ApiService api = ApiService();
  final ZoneStatusSource source;

  // --- Zonas del invernadero ---
  final ValueNotifier<Map<String, ZoneStatus>> zones = ValueNotifier(const {});

  /// Zona que se muestra en el Dashboard y en el Detalle.
  final ValueNotifier<ZoneStatus?> currentZone = ValueNotifier(null);
  final ValueNotifier<List<AlertItem>> alerts = ValueNotifier(const []);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  /// true cuando lo que se muestra viene de la caché local porque no hay
  /// conexión con Firestore (señal típica en campo / red rural).
  final ValueNotifier<bool> offline = ValueNotifier(false);

  // --- Clima de la ubicación (OpenWeather) ---
  final ValueNotifier<CurrentWeather?> weather = ValueNotifier(null);
  final ValueNotifier<bool> weatherLoading = ValueNotifier(false);
  final ValueNotifier<String?> weatherError = ValueNotifier(null);

  StreamSubscription<ZoneStatusSnapshot>? _subscription;
  Timer? _offlineTimer;
  String _greenhouseId = defaultGreenhouseId;
  String? _selectedZoneId;

  final Map<HydroVariable, bool> _notif = {
    for (final v in HydroVariable.values) v: true,
  };
  final Map<String, EstadoNivel> _ultimoNivelNotificado = {};

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    for (final v in HydroVariable.values) {
      _notif[v] = prefs.getBool(_notifKey(v)) ?? true;
    }
  }

  String _notifKey(HydroVariable v) => 'notif_${v.name}';

  bool notifEnabled(HydroVariable v) => _notif[v] ?? true;

  Future<void> setNotifPref(HydroVariable v, bool value) async {
    // Actualiza el campo en memoria de inmediato (sincrono) para que la UI
    // (setState en ProfileScreen) refleje el cambio en el mismo frame; la
    // escritura a SharedPreferences puede tardar y va después.
    _notif[v] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey(v), value);
  }

  String get currentLocation => api.currentLocation;

  String get greenhouseId => _greenhouseId;

  /// Cambia la zona que se muestra. Ignora ids que no existen.
  void selectZone(String zoneId) {
    final zone = zones.value[zoneId];
    if (zone == null) return;
    _selectedZoneId = zoneId;
    currentZone.value = zone;
  }

  /// Se suscribe en tiempo real al estado del invernadero. Llamarlo de
  /// nuevo cancela la suscripción anterior (sirve como "reintentar" o para
  /// cambiar de invernadero).
  Future<void> start({String? greenhouseId}) async {
    _greenhouseId = greenhouseId ?? _greenhouseId;
    await _subscription?.cancel();
    _subscription = null;
    error.value = null;

    // Arranque en frío sin red: pinta el último estado guardado mientras
    // llega el primer snapshot (o si nunca llega).
    if (zones.value.isEmpty) {
      final cached = await _loadCachedZones();
      if (cached.isNotEmpty && zones.value.isEmpty) {
        _publish(cached);
        alerts.value = _alertsFor(cached);
      }
    }

    if (source.requiresFirebase && !firebaseReady) {
      loading.value = false;
      error.value = 'Firebase no está configurado en este dispositivo';
      return;
    }

    loading.value = true;
    _subscription = source.watchZones(_greenhouseId).listen(
      _onSnapshot,
      onError: (Object e) {
        loading.value = false;
        error.value = 'No se pudo leer los sensores: $e';
      },
    );
  }

  void _onSnapshot(ZoneStatusSnapshot snap) {
    loading.value = false;
    error.value = null;
    _updateOffline(snap.fromCache);
    // Documento inexistente: dejamos el último estado conocido (si lo hay)
    // y la UI muestra "Esperando datos del invernadero".
    if (snap.zones.isEmpty) return;
    _publish(snap.zones);
    _refreshAlerts(snap.zones);
    if (!snap.fromCache) _saveCachedZones(snap.zones);
  }

  /// Publica las zonas y mantiene la seleccionada; si ya no existe (o no
  /// había ninguna), toma la primera en orden alfabético.
  void _publish(Map<String, ZoneStatus> nuevas) {
    zones.value = nuevas;
    final id = nuevas.containsKey(_selectedZoneId)
        ? _selectedZoneId!
        : (nuevas.keys.toList()..sort()).first;
    _selectedZoneId = id;
    currentZone.value = nuevas[id];
  }

  void _updateOffline(bool fromCache) {
    if (!fromCache) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      offline.value = false;
      return;
    }
    if (offline.value || _offlineTimer != null) return;
    _offlineTimer = Timer(offlineDelay, () {
      _offlineTimer = null;
      offline.value = true;
    });
  }

  String get _cacheKey => 'ultimo_estado_$_greenhouseId';

  Future<Map<String, ZoneStatus>> _loadCachedZones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return const {};
      return ZoneStatusAdapter.zonesFromDocument(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('SensorDataController: caché local ilegible ($e)');
      return const {};
    }
  }

  Future<void> _saveCachedZones(Map<String, ZoneStatus> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          for (final e in data.entries) e.key: ZoneStatusAdapter.toFirestore(e.value),
        }),
      );
    } catch (e) {
      debugPrint('SensorDataController: no se pudo guardar la caché ($e)');
    }
  }

  /// Re-suscribe los sensores y recarga el clima de la ubicación.
  Future<void> refresh() async {
    await Future.wait([start(), loadRealWeather()]);
  }

  Future<void> stop() async {
    _offlineTimer?.cancel();
    _offlineTimer = null;
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
      weather.value = await api.getCurrentWeather();
    } catch (e) {
      weatherError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      weatherLoading.value = false;
    }
  }

  /// Una alerta por cada variable que el backend no reporta como `ok`, en
  /// todas las zonas. Si no hay ninguna, una sola entrada "resuelta".
  List<AlertItem> _alertsFor(Map<String, ZoneStatus> data) {
    final items = <AlertItem>[];
    final ids = data.keys.toList()..sort();
    for (final zoneId in ids) {
      final zone = data[zoneId]!;
      for (final v in HydroVariable.values) {
        final m = zone[v];
        if (m == null || m.level == EstadoNivel.normal) continue;
        final valor = v.display(m.value);
        items.add(AlertItem(
          id: '$zoneId-${v.name}-${zone.timestamp.millisecondsSinceEpoch}',
          mensaje: m.level == EstadoNivel.critico
              ? '$zoneId · ${v.label} en nivel crítico ($valor)'
              : '$zoneId · ${v.label} fuera de rango ($valor)',
          nivel: m.level,
          fecha: zone.timestamp,
          activa: true,
        ));
      }
    }
    if (items.isEmpty) {
      final fecha = data.values.first.timestamp;
      items.add(AlertItem(
        id: 'normal-${fecha.millisecondsSinceEpoch}',
        mensaje: 'Condiciones óptimas en todas las zonas',
        nivel: EstadoNivel.normal,
        fecha: fecha,
        activa: false,
      ));
    }
    return items;
  }

  void _refreshAlerts(Map<String, ZoneStatus> data) {
    alerts.value = _alertsFor(data);

    for (final MapEntry(key: zoneId, value: zone) in data.entries) {
      final nivel = zone.overallLevel;
      // Solo notificamos cuando el nivel de la zona CAMBIA respecto al
      // último aviso, para no repetir la misma notificación con cada
      // emisión del stream.
      if (nivel != EstadoNivel.normal &&
          nivel != _ultimoNivelNotificado[zoneId]) {
        for (final v in HydroVariable.values) {
          final m = zone[v];
          if (m == null || m.level == EstadoNivel.normal) continue;
          if (!notifEnabled(v)) continue;
          NotificationService.instance.showAlert(AlertItem(
            id: '$zoneId-${v.name}',
            mensaje: '$zoneId · ${v.label}: ${v.display(m.value)}',
            nivel: m.level,
            fecha: zone.timestamp,
            activa: true,
          ));
        }
      }
      _ultimoNivelNotificado[zoneId] = nivel;
    }
  }
}
