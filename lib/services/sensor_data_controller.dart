import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../adapters/zone_status_adapter.dart';
import '../models/zone_status.dart';
import 'app_status.dart';
import 'zone_status_source.dart';

/// Fuente única del estado "activo" del invernadero.
///
/// Las zonas llegan en tiempo real desde un [ZoneStatusSource]:
/// [FirestoreZoneStatusSource] (`greenhouses/{id}/state/latest`) con sesión
/// iniciada, o `MockZoneStatusSource` en el modo demo (ver DataSources). Los
/// niveles (semáforo) los calcula el backend; aquí solo se leen. Dashboard y
/// Detalle leen de aquí, así que siempre están sincronizados entre sí. Las
/// alertas NO se calculan aquí: llegan del backend (AlertsController).
class SensorDataController {
  SensorDataController._internal({
    ZoneStatusSource? source,
    this.offlineDelay = const Duration(seconds: 3),
  }) : _source = source ?? FirestoreZoneStatusSource();
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

  ZoneStatusSource _source;
  ZoneStatusSource get source => _source;

  /// Cambia la fuente (Firestore ↔ demo). Toma efecto en el próximo [start].
  void useSource(ZoneStatusSource source) => _source = source;

  // --- Zonas del invernadero ---
  final ValueNotifier<Map<String, ZoneStatus>> zones = ValueNotifier(const {});

  /// Zona que se muestra en el Dashboard y en el Detalle.
  final ValueNotifier<ZoneStatus?> currentZone = ValueNotifier(null);
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  /// true cuando lo que se muestra viene de la caché local porque no hay
  /// conexión con Firestore (señal típica en campo / red rural).
  final ValueNotifier<bool> offline = ValueNotifier(false);

  StreamSubscription<ZoneStatusSnapshot>? _subscription;
  Timer? _offlineTimer;
  String? _greenhouseId;
  String? _selectedZoneId;

  final Map<HydroVariable, bool> _notif = {
    for (final v in HydroVariable.values) v: true,
  };

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

  String? get greenhouseId => _greenhouseId;

  /// Cambia la zona que se muestra. Ignora ids que no existen.
  void selectZone(String zoneId) {
    final zone = zones.value[zoneId];
    if (zone == null) return;
    _selectedZoneId = zoneId;
    currentZone.value = zone;
  }

  /// Se suscribe en tiempo real al estado del invernadero. Llamarlo de
  /// nuevo cancela la suscripción anterior (sirve como "reintentar" o para
  /// cambiar de invernadero). Sin [greenhouseId] reusa el último.
  Future<void> start({String? greenhouseId}) async {
    if (greenhouseId != null && greenhouseId != _greenhouseId) {
      // Otro invernadero: no mezclar sus zonas con las del anterior.
      _greenhouseId = greenhouseId;
      _selectedZoneId = null;
      zones.value = const {};
      currentZone.value = null;
    }
    await _subscription?.cancel();
    _subscription = null;
    error.value = null;
    final gh = _greenhouseId;
    if (gh == null) {
      loading.value = false;
      error.value = 'Elige un invernadero';
      return;
    }

    // Arranque en frío sin red: pinta el último estado guardado mientras
    // llega el primer snapshot (o si nunca llega).
    if (zones.value.isEmpty) {
      final cached = await _loadCachedZones();
      if (cached.isNotEmpty && zones.value.isEmpty) {
        _publish(cached);
      }
    }

    if (source.requiresFirebase && !firebaseReady) {
      loading.value = false;
      error.value = 'Firebase no está configurado en este dispositivo';
      return;
    }

    loading.value = true;
    _subscription = source.watchZones(gh).listen(
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

  /// Detiene la suscripción y olvida el invernadero (al cerrar sesión).
  Future<void> reset() async {
    await stop();
    _greenhouseId = null;
    _selectedZoneId = null;
    zones.value = const {};
    currentZone.value = null;
    offline.value = false;
    error.value = null;
  }

  Future<void> stop() async {
    _offlineTimer?.cancel();
    _offlineTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
