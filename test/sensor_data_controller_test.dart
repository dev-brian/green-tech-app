import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/services/app_status.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/services/zone_status_source.dart';

/// Fuente controlada por la prueba: lo que se agrega a [controller] es lo
/// que "llega" del backend. Simula Firestore (requiere Firebase).
class _FakeSource implements ZoneStatusSource {
  final controller = StreamController<ZoneStatusSnapshot>.broadcast();

  @override
  bool get requiresFirebase => true;

  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) =>
      controller.stream;
}

ZoneStatus _zona(
  String id, {
  double ph = 6.0,
  EstadoNivel phLevel = EstadoNivel.normal,
}) =>
    ZoneStatus(
      zoneId: id,
      timestamp: DateTime.now(),
      airTemp: const Measurement(value: 22.5, level: EstadoNivel.normal),
      ph: Measurement(value: ph, level: phLevel),
      tankLevel: const Measurement(value: 78, level: EstadoNivel.normal),
    );

ZoneStatusSnapshot _snap(List<ZoneStatus> zonas, {bool fromCache = false}) =>
    ZoneStatusSnapshot(
      zones: {for (final z in zonas) z.zoneId: z},
      fromCache: fromCache,
    );

void main() {
  late _FakeSource source;
  late SensorDataController sut;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebaseReady = true;
    source = _FakeSource();
    sut = SensorDataController.forTesting(source);
  });

  tearDown(() async {
    await sut.stop();
    await source.controller.close();
  });

  test('publica cada estado del stream y genera alertas con su level',
      () async {
    await sut.start();
    expect(sut.loading.value, isTrue);

    source.controller.add(_snap([_zona('zona-1')]));
    await Future<void>.delayed(Duration.zero);

    expect(sut.loading.value, isFalse);
    expect(sut.currentZone.value?.ph?.value, 6.0);
    expect(sut.alerts.value.single.nivel, EstadoNivel.normal);

    // El nivel lo decide el backend: un pH "normal" marcado como crítico
    // se muestra como crítico, sin que la app lo recalcule.
    source.controller
        .add(_snap([_zona('zona-1', ph: 6.0, phLevel: EstadoNivel.critico)]));
    await Future<void>.delayed(Duration.zero);

    expect(sut.currentZone.value?.overallLevel, EstadoNivel.critico);
    final alerta = sut.alerts.value.single;
    expect(alerta.nivel, EstadoNivel.critico);
    expect(alerta.mensaje, contains('pH'));
    expect(alerta.mensaje, contains('zona-1'));
  });

  test('genera alertas de todas las zonas', () async {
    await sut.start();
    source.controller.add(_snap([
      _zona('zona-1', ph: 7.6, phLevel: EstadoNivel.critico),
      _zona('zona-2', ph: 6.8, phLevel: EstadoNivel.alerta),
    ]));
    await Future<void>.delayed(Duration.zero);

    expect(sut.alerts.value.map((a) => a.nivel),
        [EstadoNivel.critico, EstadoNivel.alerta]);
  });

  test('muestra la primera zona y permite cambiar entre zonas', () async {
    await sut.start();
    source.controller.add(_snap([_zona('zona-2'), _zona('zona-1')]));
    await Future<void>.delayed(Duration.zero);
    expect(sut.currentZone.value?.zoneId, 'zona-1');

    sut.selectZone('zona-2');
    expect(sut.currentZone.value?.zoneId, 'zona-2');

    // La selección se conserva con cada emisión nueva.
    source.controller.add(_snap([_zona('zona-1'), _zona('zona-2', ph: 6.4)]));
    await Future<void>.delayed(Duration.zero);
    expect(sut.currentZone.value?.zoneId, 'zona-2');
    expect(sut.currentZone.value?.ph?.value, 6.4);

    sut.selectZone('no-existe');
    expect(sut.currentZone.value?.zoneId, 'zona-2');
  });

  test('si el documento desaparece conserva el último estado', () async {
    await sut.start();
    source.controller.add(_snap([_zona('zona-1')]));
    source.controller.add(_snap(const []));
    await Future<void>.delayed(Duration.zero);

    expect(sut.currentZone.value?.zoneId, 'zona-1');
    expect(sut.error.value, isNull);
  });

  test('un error del stream se muestra sin tumbar la app', () async {
    await sut.start();
    source.controller.addError(Exception('permission-denied'));
    await Future<void>.delayed(Duration.zero);

    expect(sut.loading.value, isFalse);
    expect(sut.error.value, contains('permission-denied'));
  });

  test('sin Firebase no se suscribe a una fuente que lo requiere', () async {
    firebaseReady = false;
    await sut.start();

    expect(source.controller.hasListener, isFalse);
    expect(sut.loading.value, isFalse);
    expect(sut.error.value, contains('Firebase'));
  });

  test('las preferencias de notificación son por variable', () async {
    await sut.init();
    expect(sut.notifEnabled(HydroVariable.ph), isTrue);

    await sut.setNotifPref(HydroVariable.ph, false);
    expect(sut.notifEnabled(HydroVariable.ph), isFalse);
    expect(sut.notifEnabled(HydroVariable.ec), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notif_ph'), isFalse);
  });

  group('modo offline (Task 2.3)', () {
    test('avisa "sin conexión" solo con datos de caché y lo quita al volver',
        () async {
      await sut.start();

      source.controller.add(_snap([_zona('zona-1')], fromCache: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(sut.offline.value, isTrue);
      expect(sut.currentZone.value, isNotNull);

      source.controller.add(_snap([_zona('zona-1')]));
      await Future<void>.delayed(Duration.zero);
      expect(sut.offline.value, isFalse);
    });

    test('no parpadea si el servidor responde antes del margen', () async {
      final lento = SensorDataController.forTesting(source,
          offlineDelay: const Duration(milliseconds: 200));
      await lento.start();

      source.controller.add(_snap([_zona('zona-1')], fromCache: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.controller.add(_snap([_zona('zona-1')]));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(lento.offline.value, isFalse);
      await lento.stop();
    });

    test('guarda el último estado del servidor y lo usa en un arranque en frío',
        () async {
      await sut.start();
      source.controller.add(_snap(
          [_zona('zona-1', ph: 7.4, phLevel: EstadoNivel.critico)]));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final prefs = await SharedPreferences.getInstance();
      final guardado = jsonDecode(prefs.getString(
              'ultimo_estado_${SensorDataController.defaultGreenhouseId}')!)
          as Map<String, dynamic>;
      expect(guardado['zona-1']['ph'], {'value': 7.4, 'level': 'critical'});

      // Nueva instancia (app reabierta) sin red: aún no llega ningún snapshot.
      final reabierta = SensorDataController.forTesting(_FakeSource());
      await reabierta.start();
      expect(reabierta.currentZone.value?.ph,
          const Measurement(value: 7.4, level: EstadoNivel.critico));
      expect(reabierta.alerts.value.single.nivel, EstadoNivel.critico);
      await reabierta.stop();
    });
  });
}
