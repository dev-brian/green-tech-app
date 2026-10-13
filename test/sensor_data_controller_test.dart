import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/services/app_status.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/services/telemetry_repository.dart';

/// Repositorio controlado por la prueba: lo que se agrega a [controller]
/// es lo que "llega" de Firestore.
class _FakeRepository implements TelemetryRepository {
  final controller = StreamController<TelemetrySnapshot>.broadcast();

  @override
  Stream<TelemetrySnapshot> watchReading(String sensorId) => controller.stream;
}

SensorReading _lectura({double temperatura = 24.5}) => SensorReading(
      sensorId: 'ESP32-01',
      ubicacion: 'Zona Tomate A',
      temperatura: temperatura,
      humedadAire: 65,
      humedadSuelo: 70,
      timestamp: DateTime.now(),
    );

void main() {
  late _FakeRepository repo;
  late SensorDataController sut;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebaseReady = true;
    repo = _FakeRepository();
    sut = SensorDataController.forTesting(repo);
  });

  tearDown(() async {
    await sut.stop();
    await repo.controller.close();
  });

  test('publica cada lectura del stream y genera sus alertas', () async {
    await sut.start();
    expect(sut.loading.value, isTrue);

    repo.controller.add(TelemetrySnapshot(reading: _lectura(), fromCache: false));
    await Future<void>.delayed(Duration.zero);

    expect(sut.loading.value, isFalse);
    expect(sut.currentReading.value?.temperatura, 24.5);
    expect(sut.alerts.value.single.nivel, EstadoNivel.normal);

    repo.controller.add(
        TelemetrySnapshot(reading: _lectura(temperatura: 35), fromCache: false));
    await Future<void>.delayed(Duration.zero);

    expect(sut.currentReading.value?.estadoGeneral, EstadoNivel.critico);
    expect(sut.alerts.value.any((a) => a.nivel == EstadoNivel.critico), isTrue);
  });

  test('si el documento desaparece conserva la última lectura', () async {
    await sut.start();
    repo.controller.add(TelemetrySnapshot(reading: _lectura(), fromCache: false));
    repo.controller.add(const TelemetrySnapshot(reading: null, fromCache: false));
    await Future<void>.delayed(Duration.zero);

    expect(sut.currentReading.value?.temperatura, 24.5);
    expect(sut.error.value, isNull);
  });

  test('un error del stream se muestra sin tumbar la app', () async {
    await sut.start();
    repo.controller.addError(Exception('permission-denied'));
    await Future<void>.delayed(Duration.zero);

    expect(sut.loading.value, isFalse);
    expect(sut.error.value, contains('permission-denied'));
  });

  test('sin Firebase no se suscribe y deja un mensaje claro', () async {
    firebaseReady = false;
    await sut.start();

    expect(repo.controller.hasListener, isFalse);
    expect(sut.loading.value, isFalse);
    expect(sut.error.value, contains('Firebase'));
  });

  group('modo offline (Task 2.3)', () {
    test('avisa "sin conexión" solo con datos de caché y lo quita al volver',
        () async {
      await sut.start();

      repo.controller.add(TelemetrySnapshot(reading: _lectura(), fromCache: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(sut.offline.value, isTrue);
      expect(sut.currentReading.value, isNotNull);

      repo.controller.add(TelemetrySnapshot(reading: _lectura(), fromCache: false));
      await Future<void>.delayed(Duration.zero);
      expect(sut.offline.value, isFalse);
    });

    test('no parpadea si el servidor responde antes del margen', () async {
      final lento = SensorDataController.forTesting(repo,
          offlineDelay: const Duration(milliseconds: 200));
      await lento.start();

      repo.controller.add(TelemetrySnapshot(reading: _lectura(), fromCache: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repo.controller.add(TelemetrySnapshot(reading: _lectura(), fromCache: false));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(lento.offline.value, isFalse);
      await lento.stop();
    });

    test('guarda la última lectura del servidor y la usa en un arranque en frío',
        () async {
      await sut.start();
      repo.controller.add(
          TelemetrySnapshot(reading: _lectura(temperatura: 27.5), fromCache: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final prefs = await SharedPreferences.getInstance();
      final guardada = jsonDecode(prefs.getString('ultima_lectura_ESP32-01')!)
          as Map<String, dynamic>;
      expect(guardada['temperatura'], 27.5);

      // Nueva instancia (app reabierta) sin red: aún no llega ningún snapshot.
      final reabierta = SensorDataController.forTesting(_FakeRepository());
      await reabierta.start();
      expect(reabierta.currentReading.value?.temperatura, 27.5);
      expect(reabierta.alerts.value, isNotEmpty);
      await reabierta.stop();
    });
  });
}
