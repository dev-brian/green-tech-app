import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/greenhouse.dart';
import 'greenhouse_repository.dart';
import 'mock_zone_status_source.dart';
import 'sensor_data_controller.dart';
import 'zone_status_source.dart';

/// Resultado de cargar los invernaderos del usuario.
enum GreenhouseLoadResult {
  /// Hay un invernadero activo y los sensores ya están suscritos.
  ready,

  /// El usuario no pertenece a ningún invernadero: hay que unirse.
  none,

  /// No se pudo consultar y no hay ninguno guardado en el dispositivo.
  error,
}

/// Invernadero activo de la sesión (Singleton).
///
/// Es el equivalente móvil del `activeWorkspace` de la PWA: carga los
/// invernaderos del usuario, recuerda el último elegido en el dispositivo
/// y conecta [SensorDataController] a la fuente correcta.
class GreenhouseSession {
  GreenhouseSession._({
    GreenhouseRepository? repository,
    SensorDataController? sensors,
    ZoneStatusSource Function()? liveSource,
  })  : _repository = repository,
        _sensors = sensors,
        _liveSource = liveSource ?? (() => FirestoreZoneStatusSource());

  static final GreenhouseSession instance = GreenhouseSession._();

  @visibleForTesting
  factory GreenhouseSession.forTesting({
    required GreenhouseRepository repository,
    required SensorDataController sensors,
    required ZoneStatusSource Function() liveSource,
  }) =>
      GreenhouseSession._(
        repository: repository,
        sensors: sensors,
        liveSource: liveSource,
      );

  GreenhouseRepository? _repository;
  GreenhouseRepository get repository =>
      _repository ??= FirestoreGreenhouseRepository();

  final SensorDataController? _sensors;
  SensorDataController get sensors =>
      _sensors ?? SensorDataController.instance;

  final ZoneStatusSource Function() _liveSource;

  static const _kActive = 'active_greenhouse';

  /// Id ficticio del modo demostración (sin cuenta).
  static const demoGreenhouse = Greenhouse(
    id: 'demo',
    name: 'Invernadero demo',
    role: GreenhouseRole.operador,
  );

  final ValueNotifier<List<Greenhouse>> greenhouses = ValueNotifier(const []);
  final ValueNotifier<Greenhouse?> active = ValueNotifier(null);

  /// true cuando se entra con "Ver demostración sin cuenta": datos de prueba.
  bool get isDemo => active.value?.id == demoGreenhouse.id;

  /// Carga los invernaderos de [uid] y activa el último usado (o el
  /// primero). Sin red y sin caché de Firestore, usa el último invernadero
  /// guardado en el dispositivo para que la app abra igual en campo.
  Future<GreenhouseLoadResult> load(String uid) async {
    final saved = await _loadSaved();
    List<Greenhouse> list;
    try {
      list = await repository.fetchForUser(uid);
    } catch (e) {
      debugPrint('GreenhouseSession: no se pudieron leer invernaderos ($e)');
      if (saved == null) return GreenhouseLoadResult.error;
      greenhouses.value = [saved];
      await _activate(saved);
      return GreenhouseLoadResult.ready;
    }

    greenhouses.value = list;
    if (list.isEmpty) {
      active.value = null;
      await sensors.stop();
      return GreenhouseLoadResult.none;
    }
    final elegido = list.firstWhere(
      (g) => g.id == saved?.id,
      orElse: () => list.first,
    );
    await _activate(elegido);
    return GreenhouseLoadResult.ready;
  }

  /// Cambia de invernadero (selector del Dashboard).
  Future<void> select(Greenhouse greenhouse) async {
    if (greenhouse.id == active.value?.id) return;
    await _activate(greenhouse);
  }

  /// Une al usuario con un código y activa ese invernadero.
  Future<void> join({
    required String uid,
    required String code,
    String? email,
    String? name,
  }) async {
    final id = await repository.joinByCode(
      uid: uid,
      code: code,
      email: email,
      name: name,
    );
    final list = await repository.fetchForUser(uid);
    greenhouses.value = list;
    final nuevo = list.firstWhere(
      (g) => g.id == id,
      orElse: () =>
          Greenhouse(id: id, name: 'Invernadero', role: GreenhouseRole.operador),
    );
    await _activate(nuevo);
  }

  /// Modo demostración: datos de prueba, sin Firebase.
  Future<void> enterDemo() async {
    greenhouses.value = const [demoGreenhouse];
    active.value = demoGreenhouse;
    sensors.useSource(MockZoneStatusSource());
    await sensors.start(greenhouseId: demoGreenhouse.id);
  }

  /// Al cerrar sesión: olvida el invernadero y corta la suscripción.
  Future<void> clear() async {
    await sensors.reset();
    greenhouses.value = const [];
    active.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActive);
  }

  Future<void> _activate(Greenhouse greenhouse) async {
    active.value = greenhouse;
    // Si venía del modo demo, vuelve a la fuente real.
    if (!sensors.source.requiresFirebase) sensors.useSource(_liveSource());
    await sensors.start(greenhouseId: greenhouse.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActive, jsonEncode(greenhouse.toJson()));
  }

  Future<Greenhouse?> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActive);
      return raw == null ? null : Greenhouse.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
