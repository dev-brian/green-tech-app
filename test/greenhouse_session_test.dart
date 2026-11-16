import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/greenhouse.dart';
import 'package:greentech_app/repositories/alerts_repository.dart';
import 'package:greentech_app/repositories/greenhouse_repository.dart';
import 'package:greentech_app/services/alerts_controller.dart';
import 'package:greentech_app/services/app_status.dart';
import 'package:greentech_app/services/greenhouse_session.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/services/zone_status_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGreenhouses implements GreenhouseRepository {
  List<Greenhouse> lista = [];
  String? unidoCon;

  @override
  Future<List<Greenhouse>> myGreenhouses(String uid) async => lista;

  @override
  Future<String> joinWithCode(
      {required String code, required String uid, String? email, String? name}) async {
    unidoCon = code;
    const nuevo = Greenhouse(id: 'gh-nuevo', name: 'Nuevo');
    lista = [...lista, nuevo];
    return nuevo.id;
  }
}

class _FakeZones implements ZoneStatusSource {
  final pedidos = <String>[];
  @override
  bool get requiresFirebase => true;
  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) {
    pedidos.add(greenhouseId);
    return const Stream.empty();
  }
}

class _FakeAlerts implements AlertsRepository {
  final pedidos = <String>[];
  @override
  Stream<AlertsSnapshot> watch(String greenhouseId) {
    pedidos.add(greenhouseId);
    return const Stream.empty();
  }

  @override
  Future<void> attend(String g, String a, String u) async {}
}

void main() {
  late _FakeGreenhouses repo;
  late _FakeZones zones;
  late _FakeAlerts alerts;
  late GreenhouseSession sut;

  const a = Greenhouse(id: 'gh-a', name: 'A', role: GreenhouseRole.admin);
  const b = Greenhouse(id: 'gh-b', name: 'B', role: GreenhouseRole.operador);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebaseReady = true;
    repo = _FakeGreenhouses();
    zones = _FakeZones();
    alerts = _FakeAlerts();
    sut = GreenhouseSession.forTesting(
      repository: repo,
      sensors: SensorDataController.forTesting(zones),
      alerts: AlertsController.forTesting(alerts, notify: (_) {}),
      currentUid: () => 'uid-1',
    );
  });

  test('sin invernaderos pide el código', () async {
    expect(await sut.load(), GreenhouseLoadResult.join);
    expect(sut.current.value, isNull);
  });

  test('con uno solo entra directo y arranca zonas y alertas', () async {
    repo.lista = [a];
    expect(await sut.load(), GreenhouseLoadResult.ready);
    expect(sut.current.value, a);
    expect(zones.pedidos, ['gh-a']);
    expect(alerts.pedidos, ['gh-a']);
  });

  test('con varios pide elegir, y la próxima vez recuerda el elegido',
      () async {
    repo.lista = [a, b];
    expect(await sut.load(), GreenhouseLoadResult.pick);
    await sut.select(b);
    expect(zones.pedidos, ['gh-b']);

    expect(await sut.load(), GreenhouseLoadResult.ready);
    expect(sut.current.value, b);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('invernadero_elegido_uid-1'), 'gh-b');
  });

  test('unirse con código entra a ese invernadero', () async {
    repo.lista = [a];
    await sut.joinWithCode('abc123');
    expect(repo.unidoCon, 'abc123');
    expect(sut.current.value?.id, 'gh-nuevo');
    expect(zones.pedidos.last, 'gh-nuevo');
  });

  test('clear olvida el invernadero', () async {
    repo.lista = [a];
    await sut.load();
    await sut.clear();
    expect(sut.current.value, isNull);
    expect(sut.greenhouses.value, isEmpty);
  });

  test('modo demo usa fuentes de prueba', () async {
    final s = GreenhouseSession.forTesting(
      repository: repo,
      sensors: SensorDataController.forTesting(zones),
      alerts: AlertsController.forTesting(alerts, notify: (_) {}),
      currentUid: () => null,
    );
    await s.startDemo();
    expect(s.isDemo, isTrue);
    expect(s.current.value?.id, 'demo');
    expect(zones.pedidos, isEmpty); // ya no usa la fuente de Firestore
    await s.clear();
  });
}
