import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/greenhouse.dart';
import '../repositories/greenhouse_repository.dart';
import 'alerts_controller.dart';
import 'data_sources.dart';
import 'firebase_service.dart';
import 'sensor_data_controller.dart';

/// Qué debe mostrar la app después de cargar los invernaderos del usuario.
enum GreenhouseLoadResult {
  /// Ya hay invernadero elegido: ir al Dashboard.
  ready,

  /// Es miembro de varios y no hay uno guardado: mostrar el selector.
  pick,

  /// No es miembro de ninguno: pedir el código de invitación.
  join,
}

/// Facade de la sesión de trabajo: qué invernadero se está viendo y con qué
/// fuentes de datos.
///
/// Las pantallas solo hablan con esta clase para elegir invernadero, unirse
/// con código, entrar en modo demo o cerrar sesión. Por dentro coordina el
/// repositorio de invernaderos, [SensorDataController] (zonas en vivo),
/// [AlertsController] (bandeja de alertas) y las [DataSources] que usan el
/// histórico y los actuadores.
class GreenhouseSession {
  GreenhouseSession._internal({
    GreenhouseRepository? repository,
    SensorDataController? sensors,
    AlertsController? alerts,
    String? Function()? currentUid,
    ({String? email, String? name}) Function()? currentProfile,
  })  : _repository = repository ?? FirestoreGreenhouseRepository(),
        _sensors = sensors ?? SensorDataController.instance,
        _alerts = alerts ?? AlertsController.instance,
        _currentUid =
            currentUid ?? (() => FirebaseService.instance.currentUser?.uid),
        _currentProfile = currentProfile ??
            (() {
              final u = FirebaseService.instance.currentUser;
              return (email: u?.email, name: u?.displayName);
            });

  static final GreenhouseSession instance = GreenhouseSession._internal();

  @visibleForTesting
  factory GreenhouseSession.forTesting({
    required GreenhouseRepository repository,
    required SensorDataController sensors,
    required AlertsController alerts,
    required String? Function() currentUid,
  }) =>
      GreenhouseSession._internal(
        repository: repository,
        sensors: sensors,
        alerts: alerts,
        currentUid: currentUid,
        currentProfile: () => (email: null, name: null),
      );

  final GreenhouseRepository _repository;
  final SensorDataController _sensors;
  final AlertsController _alerts;
  final String? Function() _currentUid;
  final ({String? email, String? name}) Function() _currentProfile;

  /// Invernaderos del usuario (para el selector).
  final ValueNotifier<List<Greenhouse>> greenhouses = ValueNotifier(const []);

  /// Invernadero que se está viendo.
  final ValueNotifier<Greenhouse?> current = ValueNotifier(null);

  DataSources _sources = DataSources.firestore();
  DataSources get sources => _sources;
  bool get isDemo => _sources.isDemo;

  String? get uid => _currentUid();

  static String _prefKey(String uid) => 'invernadero_elegido_$uid';

  /// Carga los invernaderos del usuario y, si puede, deja uno elegido: el
  /// último que usó en este celular, o el único que tiene.
  Future<GreenhouseLoadResult> load() async {
    final uid = _currentUid();
    if (uid == null) {
      throw const GreenhouseException('Inicia sesión para ver tus invernaderos');
    }
    _usarFirestore();
    final list = await _repository.myGreenhouses(uid);
    greenhouses.value = list;
    if (list.isEmpty) return GreenhouseLoadResult.join;

    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_prefKey(uid));
    final elegido = list.where((g) => g.id == guardado).firstOrNull ??
        (list.length == 1 ? list.single : null);
    if (elegido == null) return GreenhouseLoadResult.pick;
    await select(elegido);
    return GreenhouseLoadResult.ready;
  }

  /// Cambia al invernadero [greenhouse] y lo recuerda para la próxima vez.
  Future<void> select(Greenhouse greenhouse) async {
    current.value = greenhouse;
    final uid = _currentUid();
    if (uid != null && !isDemo) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(uid), greenhouse.id);
    }
    await _sensors.start(greenhouseId: greenhouse.id);
    await _alerts.start(greenhouse.id);
  }

  /// Une al usuario con un código de invitación y entra a ese invernadero.
  Future<void> joinWithCode(String code) async {
    final uid = _currentUid();
    if (uid == null) {
      throw const GreenhouseException('Inicia sesión para unirte');
    }
    final perfil = _currentProfile();
    final id = await _repository.joinWithCode(
      code: code,
      uid: uid,
      email: perfil.email,
      name: perfil.name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey(uid), id);
    await load();
  }

  /// "Continuar sin cuenta": datos de prueba, sin Firestore.
  Future<void> startDemo({DataSources? sources}) async {
    _sources = sources ?? DataSources.demo();
    _sensors.useSource(_sources.zones);
    _alerts.configure(repository: _sources.alerts);
    greenhouses.value = const [];
    await select(const Greenhouse(
      id: 'demo',
      name: 'Invernadero de demostración',
      role: GreenhouseRole.operador,
    ));
  }

  /// Detiene todo y olvida el invernadero (antes de cerrar sesión).
  Future<void> clear() async {
    await _alerts.stop();
    _alerts.alerts.value = const [];
    await _sensors.reset();
    current.value = null;
    greenhouses.value = const [];
  }

  void _usarFirestore() {
    if (!_sources.isDemo) return;
    _sources = DataSources.firestore();
    _sensors.useSource(_sources.zones);
    _alerts.configure(repository: _sources.alerts);
  }
}
