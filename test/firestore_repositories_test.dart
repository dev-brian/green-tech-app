import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/actuator_state.dart';
import 'package:greentech_app/models/greenhouse.dart';
import 'package:greentech_app/models/history.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/repositories/actuators_repository.dart';
import 'package:greentech_app/repositories/alerts_repository.dart';
import 'package:greentech_app/repositories/greenhouse_repository.dart';
import 'package:greentech_app/repositories/history_repository.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('FirestoreGreenhouseRepository', () {
    late FirestoreGreenhouseRepository repo;

    setUp(() async {
      repo = FirestoreGreenhouseRepository(firestore: db);
      await db.doc('greenhouses/gh-b').set({
        'name': 'Invernadero Norte',
        'memberIds': ['uid-1', 'uid-2'],
        'inviteCode': 'NORTE1',
      });
      await db.doc('greenhouses/gh-b/members/uid-1').set({'role': 'admin'});
      await db.doc('greenhouses/gh-a').set({
        'name': 'Casa sombra',
        'memberIds': ['uid-1'],
        'inviteCode': 'CASA01',
      });
      await db.doc('greenhouses/gh-a/members/uid-1').set({'role': 'operador'});
      await db.doc('greenhouses/gh-otro').set({
        'name': 'Ajeno',
        'memberIds': ['uid-9'],
        'inviteCode': 'AJENO1',
      });
      await db.doc('greenhouse_invites/AJENO1').set({'greenhouseId': 'gh-otro'});
    });

    test('lista solo los invernaderos del usuario, con su rol', () async {
      final lista = await repo.myGreenhouses('uid-1');
      expect(lista, const [
        Greenhouse(id: 'gh-a', name: 'Casa sombra', role: GreenhouseRole.operador),
        Greenhouse(
            id: 'gh-b', name: 'Invernadero Norte', role: GreenhouseRole.admin),
      ]);
      expect(await repo.myGreenhouses('uid-sin-nada'), isEmpty);
    });

    test('se une con código como operador (mismo flujo que la PWA)', () async {
      final id = await repo.joinWithCode(
          code: ' ajeno1 ', uid: 'uid-1', email: 'op@greentech.com');
      expect(id, 'gh-otro');

      final gh = (await db.doc('greenhouses/gh-otro').get()).data()!;
      expect(gh['memberIds'], ['uid-9', 'uid-1']);
      final member = (await db.doc('greenhouses/gh-otro/members/uid-1').get()).data()!;
      expect(member['role'], 'operador');
      expect(member['inviteCode'], 'AJENO1');
      expect(member['email'], 'op@greentech.com');
    });

    test('un código que no existe da un mensaje claro', () async {
      expect(
        () => repo.joinWithCode(code: 'NOEXISTE', uid: 'uid-1'),
        throwsA(isA<GreenhouseException>()
            .having((e) => e.message, 'message', contains('no existe'))),
      );
      expect(
        () => repo.joinWithCode(code: '  ', uid: 'uid-1'),
        throwsA(isA<GreenhouseException>()),
      );
    });
  });

  group('FirestoreAlertsRepository', () {
    test('lee las alertas de la más nueva a la más vieja y atiende', () async {
      final repo = FirestoreAlertsRepository(firestore: db);
      final col = db.collection('greenhouses/gh-1/alerts');
      await col.doc('vieja').set({
        'zoneId': 'zona-1',
        'variable': 'ph',
        'severity': 'warn',
        'status': 'auto_resolved',
        'message': 'pH en precaución',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 14, 8)),
      });
      await col.doc('nueva').set({
        'zoneId': 'zona-2',
        'variable': 'tankLevel',
        'severity': 'critical',
        'status': 'new',
        'value': 12,
        'message': 'Tanque crítico',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 14, 9)),
        'attendedBy': null,
        'attendedAt': null,
      });

      final snap = await repo.watch('gh-1').first;
      expect(snap.alerts.map((a) => a.id), ['nueva', 'vieja']);
      expect(snap.alerts.first.nivel, EstadoNivel.critico);

      await repo.attend('gh-1', 'nueva', 'uid-1');
      final doc = (await col.doc('nueva').get()).data()!;
      expect(doc['status'], 'attended');
      expect(doc['attendedBy'], 'uid-1');
      expect(doc['attendedAt'], isA<Timestamp>());
      // Lo demás no se toca.
      expect(doc['severity'], 'critical');
      expect(doc['message'], 'Tanque crítico');
    });
  });

  group('FirestoreHistoryRepository', () {
    final now = DateTime(2026, 11, 14, 12);

    Future<void> lectura(String zona, DateTime t, double ph) => db
        .collection('greenhouses/gh-1/readings')
        .add({'zoneId': zona, 'timestamp': Timestamp.fromDate(t), 'ph': ph, 'ec': 1.8});

    test('24 h: lecturas de la zona, promediadas cada 5 min', () async {
      await lectura('zona-1', now.subtract(const Duration(minutes: 2)), 6.0);
      await lectura('zona-1', now.subtract(const Duration(minutes: 1)), 6.4);
      await lectura('zona-1', now.subtract(const Duration(hours: 3)), 5.8);
      await lectura('zona-2', now.subtract(const Duration(minutes: 1)), 9.9);
      await lectura('zona-1', now.subtract(const Duration(hours: 30)), 1.0);

      final repo = FirestoreHistoryRepository(firestore: db, clock: () => now);
      final h = await repo.fetch('gh-1', 'zona-1', HistoryRange.h24);
      final ph = h[HydroVariable.ph];
      expect(ph.map((p) => p.value), [5.8, closeTo(6.2, 1e-9)]);
      expect(ph.last.min, 6.0);
      expect(ph.last.max, 6.4);
      expect(h[HydroVariable.ec], hasLength(2));
      expect(h[HydroVariable.light], isEmpty);
    });

    test('7 días: promedios por hora de readingsHourly', () async {
      final col = db.collection('greenhouses/gh-1/readingsHourly');
      await col.doc('zona-1_2026111310').set({
        'zoneId': 'zona-1',
        'hour': Timestamp.fromDate(DateTime(2026, 11, 13, 10)),
        'count': 60,
        'ph': {'avg': 6.1, 'min': 5.9, 'max': 6.3},
      });
      await col.doc('zona-1_2026110110').set({
        'zoneId': 'zona-1',
        'hour': Timestamp.fromDate(DateTime(2026, 11, 1, 10)),
        'ph': {'avg': 7.0, 'min': 7.0, 'max': 7.0},
      });

      final repo = FirestoreHistoryRepository(firestore: db, clock: () => now);
      final d7 = await repo.fetch('gh-1', 'zona-1', HistoryRange.d7);
      expect(d7[HydroVariable.ph].single.value, 6.1);
      expect(d7[HydroVariable.ph].single.max, 6.3);
      final d30 = await repo.fetch('gh-1', 'zona-1', HistoryRange.d30);
      expect(d30[HydroVariable.ph], hasLength(2));
    });

    test('guarda el resultado 5 min para no gastar lecturas', () async {
      var t = now;
      final repo = FirestoreHistoryRepository(firestore: db, clock: () => t);
      await lectura('zona-1', now.subtract(const Duration(minutes: 1)), 6.0);
      expect((await repo.fetch('gh-1', 'zona-1', HistoryRange.h24))[HydroVariable.ph],
          hasLength(1));

      await lectura('zona-1', now.subtract(const Duration(minutes: 30)), 6.5);
      t = now.add(const Duration(minutes: 1));
      expect((await repo.fetch('gh-1', 'zona-1', HistoryRange.h24))[HydroVariable.ph],
          hasLength(1));
      t = now.add(const Duration(minutes: 6));
      expect((await repo.fetch('gh-1', 'zona-1', HistoryRange.h24))[HydroVariable.ph],
          hasLength(2));
    });
  });

  group('FirestoreActuatorsRepository', () {
    test('lee los 4 actuadores de la zona', () async {
      await db.doc('greenhouses/gh-1/actuators/zona-1').set({
        'zoneId': 'zona-1',
        'recirculationPump': {'on': true, 'updatedAt': '2026-11-14T10:00:00Z', 'updatedBy': 'backend'},
        'phDoser': {'on': false, 'updatedAt': '2026-11-14T10:00:00Z', 'updatedBy': 'backend'},
        'nutrientDoser': {'on': true, 'updatedAt': '2026-11-14T10:00:00Z', 'updatedBy': 'uid-1'},
        'ventilation': 'mal formado',
        'updatedAt': '2026-11-14T10:00:00Z',
      });
      final repo = FirestoreActuatorsRepository(firestore: db);
      final z = (await repo.watch('gh-1', 'zona-1').first)!;
      expect(z[ActuatorKind.recirculationPump]?.on, isTrue);
      expect(z[ActuatorKind.phDoser]?.on, isFalse);
      expect(z[ActuatorKind.nutrientDoser]?.updatedBy, 'uid-1');
      expect(z[ActuatorKind.ventilation], isNull);
      expect(z.updatedAt, isNotNull);

      expect(await repo.watch('gh-1', 'zona-9').first, isNull);
    });
  });

  test('agruparPor promedia por cubeta y conserva mín/máx', () {
    final t0 = DateTime(2026, 11, 14, 10);
    final out = agruparPor([
      HistoryPoint(t0, 1),
      HistoryPoint(t0.add(const Duration(minutes: 1)), 3),
      HistoryPoint(t0.add(const Duration(minutes: 7)), 10),
    ], const Duration(minutes: 5));
    expect(out.map((p) => p.value), [2, 10]);
    expect(out.first.min, 1);
    expect(out.first.max, 3);
  });
}
