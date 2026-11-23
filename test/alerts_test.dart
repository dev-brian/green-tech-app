import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/adapters/alert_adapter.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/repositories/alerts_repository.dart';
import 'package:greentech_app/repositories/demo_repositories.dart';
import 'package:greentech_app/screens/alerts_screen.dart';
import 'package:greentech_app/services/alerts_controller.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/utils/colors.dart';

/// Repositorio controlado por la prueba: lo que se agrega a [controller]
/// es lo que "manda" el backend.
class _FakeAlertsRepo implements AlertsRepository {
  final controller = StreamController<AlertsSnapshot>.broadcast();
  final atendidas = <String>[];
  Object? fallarCon;

  @override
  Stream<AlertsSnapshot> watch(String greenhouseId) => controller.stream;

  @override
  Future<void> attend(String greenhouseId, String alertId, String uid) async {
    if (fallarCon != null) throw fallarCon!;
    atendidas.add('$alertId:$uid');
  }
}

AlertItem _alerta(
  String id, {
  EstadoNivel nivel = EstadoNivel.critico,
  AlertStatus status = AlertStatus.nueva,
  String zona = 'zona-1',
  HydroVariable variable = HydroVariable.ph,
}) =>
    AlertItem(
      id: id,
      zoneId: zona,
      variable: variable,
      nivel: nivel,
      mensaje: 'pH en $zona',
      fecha: DateTime(2026, 11, 14, 10),
      status: status,
    );

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('AlertAdapter', () {
    test('lee una alerta del contrato v0.2', () {
      final a = AlertAdapter.fromFirestore('a1', {
        'zoneId': 'zona-2',
        'variable': 'tankLevel',
        'severity': 'critical',
        'value': 12,
        'message': 'Nivel del tanque crítico en zona-2: 12 %',
        'status': 'new',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 14, 9)),
        'attendedBy': null,
        'attendedAt': null,
        'resolvedAt': null,
      });
      expect(a.id, 'a1');
      expect(a.zoneId, 'zona-2');
      expect(a.variable, HydroVariable.tankLevel);
      expect(a.nivel, EstadoNivel.critico);
      expect(a.value, 12.0);
      expect(a.status, AlertStatus.nueva);
      expect(a.activa, isTrue);
      expect(a.fecha.isAtSameMomentAs(DateTime.utc(2026, 11, 14, 9)), isTrue);
    });

    test('warn es aviso; attended y auto_resolved no están activas', () {
      final atendida = AlertAdapter.fromFirestore('a', {
        'severity': 'warn',
        'status': 'attended',
        'attendedBy': 'uid-1',
        'attendedAt': '2026-11-14T10:00:00Z',
      });
      expect(atendida.nivel, EstadoNivel.alerta);
      expect(atendida.status, AlertStatus.atendida);
      expect(atendida.attendedBy, 'uid-1');
      expect(atendida.attendedAt, isNotNull);
      expect(atendida.activa, isFalse);

      final resuelta =
          AlertAdapter.fromFirestore('b', {'status': 'auto_resolved'});
      expect(resuelta.status, AlertStatus.autoResuelta);
    });

    test('atender solo toca los 3 campos que permiten las reglas', () {
      expect(AlertAdapter.attendPatch('uid-1', 'ahora').keys,
          unorderedEquals(['status', 'attendedBy', 'attendedAt']));
      expect(AlertAdapter.attendPatch('uid-1', 'ahora')['status'], 'attended');
    });
  });

  group('AlertsController', () {
    late _FakeAlertsRepo repo;
    late List<AlertItem> notificadas;
    late Set<HydroVariable> apagadas;
    late AlertsController sut;

    setUp(() async {
      repo = _FakeAlertsRepo();
      notificadas = [];
      apagadas = {};
      sut = AlertsController.forTesting(
        repo,
        notify: notificadas.add,
        notifEnabled: (v) => !apagadas.contains(v),
      );
      await sut.start('gh-1');
    });

    tearDown(() async {
      await sut.stop();
      await repo.controller.close();
    });

    test('muestra lo que manda el backend y cuenta las activas', () async {
      repo.controller.add(AlertsSnapshot(alerts: [
        _alerta('a'),
        _alerta('b', status: AlertStatus.autoResuelta),
      ]));
      await _tick();
      expect(sut.alerts.value.map((a) => a.id), ['a', 'b']);
      expect(sut.activas, 1);
      expect(sut.loading.value, isFalse);
    });

    test('no notifica lo que ya estaba abierto al entrar, sí lo nuevo crítico',
        () async {
      repo.controller.add(AlertsSnapshot(alerts: [_alerta('vieja')]));
      await _tick();
      expect(notificadas, isEmpty);

      repo.controller.add(AlertsSnapshot(alerts: [
        _alerta('nueva-aviso', nivel: EstadoNivel.alerta),
        _alerta('nueva-critica'),
        _alerta('vieja'),
      ]));
      await _tick();
      expect(notificadas.map((a) => a.id), ['nueva-critica']);

      // La misma alerta en la siguiente emisión no se repite.
      repo.controller.add(AlertsSnapshot(alerts: [
        _alerta('nueva-aviso', nivel: EstadoNivel.alerta),
        _alerta('nueva-critica'),
      ]));
      await _tick();
      expect(notificadas, hasLength(1));
    });

    test('en segundo plano no notifica: el push de FCM ya lo hace', () async {
      var segundoPlano = false;
      final avisos = <AlertItem>[];
      final repo2 = _FakeAlertsRepo();
      final c = AlertsController.forTesting(repo2,
          notify: avisos.add, pushLaCubre: () => segundoPlano);
      await c.start('gh-1');
      repo2.controller.add(const AlertsSnapshot(alerts: []));
      await _tick();

      segundoPlano = true;
      repo2.controller.add(AlertsSnapshot(alerts: [_alerta('a')]));
      await _tick();
      expect(avisos, isEmpty);
      expect(c.activas, 1);

      // Al volver al frente no se repite la que ya avisó el push.
      segundoPlano = false;
      repo2.controller
          .add(AlertsSnapshot(alerts: [_alerta('a'), _alerta('b')]));
      await _tick();
      expect(avisos.map((x) => x.id), ['b']);
      await c.stop();
      await repo2.controller.close();
    });

    test('notifica cuando un aviso sube a crítico', () async {
      repo.controller.add(const AlertsSnapshot(alerts: []));
      await _tick();
      repo.controller.add(
          AlertsSnapshot(alerts: [_alerta('a', nivel: EstadoNivel.alerta)]));
      await _tick();
      expect(notificadas, isEmpty);
      repo.controller.add(AlertsSnapshot(alerts: [_alerta('a')]));
      await _tick();
      expect(notificadas.single.id, 'a');
    });

    test('respeta las variables apagadas en el Perfil', () async {
      apagadas.add(HydroVariable.ph);
      repo.controller.add(const AlertsSnapshot(alerts: []));
      await _tick();
      repo.controller.add(AlertsSnapshot(alerts: [
        _alerta('ph'),
        _alerta('tanque', variable: HydroVariable.tankLevel),
      ]));
      await _tick();
      expect(notificadas.map((a) => a.id), ['tanque']);
    });

    test(
        'atender se ve al instante y se mantiene hasta que el servidor confirma',
        () async {
      repo.controller.add(AlertsSnapshot(alerts: [_alerta('a')]));
      await _tick();

      final ok = await sut.attend(sut.alerts.value.single, 'uid-1');
      expect(ok, isTrue);
      expect(repo.atendidas, ['a:uid-1']);
      expect(sut.alerts.value.single.status, AlertStatus.atendida);
      expect(sut.activas, 0);

      // Sin red, la caché aún dice `new`: la app sigue mostrándola atendida.
      repo.controller
          .add(AlertsSnapshot(alerts: [_alerta('a')], fromCache: true));
      await _tick();
      expect(sut.alerts.value.single.status, AlertStatus.atendida);
    });

    test('si el servidor rechaza, la alerta vuelve a estar activa', () async {
      repo.controller.add(AlertsSnapshot(alerts: [_alerta('a')]));
      await _tick();
      repo.fallarCon = Exception('permission-denied');

      final ok = await sut.attend(sut.alerts.value.single, 'uid-1');
      expect(ok, isFalse);
      expect(sut.alerts.value.single.activa, isTrue);
      expect(sut.error.value, contains('permission-denied'));
    });
  });

  test('filtrarAlertas por estado, severidad y zona', () {
    final todas = [
      _alerta('a', zona: 'zona-1'),
      _alerta('b', zona: 'zona-2', nivel: EstadoNivel.alerta),
      _alerta('c', status: AlertStatus.atendida),
      _alerta('d', status: AlertStatus.autoResuelta),
    ];
    List<String> ids(List<AlertItem> l) => [for (final a in l) a.id];

    expect(
        ids(filtrarAlertas(todas, estado: FiltroEstado.activas)), ['a', 'b']);
    expect(ids(filtrarAlertas(todas, estado: FiltroEstado.atendidas)), ['c']);
    expect(ids(filtrarAlertas(todas, estado: FiltroEstado.resueltas)), ['d']);
    expect(
        ids(filtrarAlertas(todas,
            estado: FiltroEstado.activas, severidad: FiltroSeveridad.criticas)),
        ['a']);
    expect(ids(filtrarAlertas(todas, zona: 'zona-2')), ['b']);
  });

  testWidgets('AlertsScreen: "Atender" en una alerta activa', (tester) async {
    final repo = _FakeAlertsRepo();
    final controller = AlertsController.forTesting(repo, notify: (_) {});
    await tester.runAsync(() => controller.start('gh-1'));
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: AlertsScreen(controller: controller, uid: 'uid-1'),
    ));
    repo.controller.add(AlertsSnapshot(alerts: [
      _alerta('a'),
      _alerta('b', status: AlertStatus.atendida),
    ]));
    await tester.pump();
    await tester.pump();

    // Filtro por defecto: solo activas.
    expect(find.text('Activa'), findsOneWidget);
    expect(find.byKey(const Key('atender_a')), findsOneWidget);

    await tester.tap(find.byKey(const Key('atender_a')));
    await tester.pump();
    expect(repo.atendidas, ['a:uid-1']);
    expect(find.text('No hay alertas activas. Todo en orden.'), findsOneWidget);

    await tester.tap(find.text('Atendidas'));
    await tester.pump();
    expect(find.text('Atendida'), findsNWidgets(2));
    expect(find.byKey(const Key('atender_a')), findsNothing);

    await tester.pump(const Duration(seconds: 4)); // cierra el SnackBar
    await tester.runAsync(controller.stop);
    await repo.controller.close();
  });

  group('MockAlertsRepository (modo demo)', () {
    test('crea, no duplica y resuelve sola como el backend', () async {
      final mock = MockZoneStatusSource(interval: const Duration(hours: 1));
      final repo = MockAlertsRepository(mock);
      final emisiones = <AlertsSnapshot>[];
      final sub = repo.watch('demo').listen(emisiones.add);
      await _tick();

      mock.setZoneScenario('zona-1', MockScenario.phAlto);
      await _tick();
      mock.setZoneScenario('zona-1', MockScenario.phAlto);
      await _tick();
      final abiertas = emisiones.last.alerts.where((a) => a.activa).toList();
      expect(abiertas, hasLength(1));
      expect(abiertas.single.variable, HydroVariable.ph);
      expect(abiertas.single.nivel, EstadoNivel.critico);

      await repo.attend('demo', abiertas.single.id, 'demo');
      expect(emisiones.last.alerts.first.status, AlertStatus.atendida);

      mock.setZoneScenario('zona-2', MockScenario.ecBaja);
      await _tick();
      mock.scenario = MockScenario.normal;
      await _tick();
      expect(emisiones.last.alerts.where((a) => a.activa), isEmpty);
      expect(emisiones.last.alerts.first.status, AlertStatus.autoResuelta);
      await sub.cancel();
    });
  });
}
