import 'dart:async';
import 'dart:math';

import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import 'zone_status_source.dart';

/// Situaciones que se pueden forzar en la fuente de prueba.
enum MockScenario {
  normal('Todo normal'),
  phAlto('pH alto'),
  ecBaja('EC baja'),
  tanqueBajo('Tanque bajo'),
  solucionCaliente('Solución caliente');

  const MockScenario(this.label);
  final String label;
}

/// Fuente de prueba: emite un estado nuevo al suscribirse y luego cada
/// [interval] (5 s por defecto), con pequeñas variaciones en los valores.
///
/// Hace las veces del backend, así que es ella quien asigna el `level` de
/// cada variable según el [scenario] forzado; la app solo lo muestra.
class MockZoneStatusSource implements ZoneStatusSource {
  MockZoneStatusSource({
    this.interval = const Duration(seconds: 5),
    this.zoneIds = const ['zona-1', 'zona-2'],
    Random? random,
    MockScenario scenario = MockScenario.normal,
  })  : _random = random ?? Random(),
        _scenario = scenario;

  final Duration interval;
  final List<String> zoneIds;
  final Random _random;
  final Set<StreamController<ZoneStatusSnapshot>> _listeners = {};

  MockScenario _scenario;
  MockScenario get scenario => _scenario;

  /// Cambia el escenario y emite de inmediato, sin esperar al siguiente
  /// intervalo, para que el cambio se vea al instante en la app.
  set scenario(MockScenario value) {
    _scenario = value;
    for (final c in _listeners) {
      c.add(_snapshot());
    }
  }

  @override
  bool get requiresFirebase => false;

  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) {
    Timer? timer;
    late final StreamController<ZoneStatusSnapshot> controller;
    controller = StreamController<ZoneStatusSnapshot>(
      onListen: () {
        _listeners.add(controller);
        controller.add(_snapshot());
        timer = Timer.periodic(interval, (_) => controller.add(_snapshot()));
      },
      onCancel: () {
        timer?.cancel();
        _listeners.remove(controller);
      },
    );
    return controller.stream;
  }

  ZoneStatusSnapshot _snapshot() {
    final now = DateTime.now();
    return ZoneStatusSnapshot(
      zones: {for (final id in zoneIds) id: _zone(id, now)},
      fromCache: false,
    );
  }

  ZoneStatus _zone(String zoneId, DateTime now) {
    Measurement m(double base, double jitter, EstadoNivel level) => Measurement(
          value: base + (_random.nextDouble() * 2 - 1) * jitter,
          level: level,
        );
    const ok = EstadoNivel.normal;
    final s = _scenario;
    return ZoneStatus(
      zoneId: zoneId,
      timestamp: now,
      airTemp: m(22.5, 0.6, ok),
      humidity: m(65, 3, ok),
      light: m(18000, 800, ok),
      ph: s == MockScenario.phAlto
          ? m(7.6, 0.1, EstadoNivel.critico)
          : m(6.0, 0.1, ok),
      ec: s == MockScenario.ecBaja
          ? m(0.8, 0.05, EstadoNivel.alerta)
          : m(1.8, 0.05, ok),
      solutionTemp: s == MockScenario.solucionCaliente
          ? m(27.5, 0.3, EstadoNivel.alerta)
          : m(20.5, 0.3, ok),
      tankLevel: s == MockScenario.tanqueBajo
          ? m(12, 1, EstadoNivel.critico)
          : m(78, 1, ok),
    );
  }
}
