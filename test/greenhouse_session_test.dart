import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greentech_app/models/greenhouse.dart';
import 'package:greentech_app/services/app_status.dart';
import 'package:greentech_app/services/greenhouse_repository.dart';
import 'package:greentech_app/services/greenhouse_session.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/services/zone_status_source.dart';

/// Fuente "real" de prueba: registra con qué invernadero se suscribió.
class _LiveSource implements ZoneStatusSource {
  final watched = <String>[];

  @override
  bool get requiresFirebase => true;

  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) {
    watched.add(greenhouseId);
    return const Stream.empty();
  }
}

/// Repositorio que falla, como si no hubiera red ni caché.
class _OfflineRepository implements GreenhouseRepository {
  @override
  Future<List<Greenhouse>> fetchForUser(String uid) =>
      Future.error(Exception('unavailable'));

  @override
  Future<String> joinByCode({
    required String uid,
    required String code,
    String? email,
    String? name,
  }) =>
      Future.error(const GreenhouseException('sin red'));
}

Future<void> _seed(FakeFirebaseFirestore db) async {
  await db.collection('greenhouses').doc('gh-b').set({
    'name': 'Zona Norte',
    'memberIds': ['u1'],
    'inviteCode': 'NORTE1',
  });
  await db
      .collection('greenhouses')
      .doc('gh-b')
      .collection('members')
      .doc('u1')
      .set({'role': 'admin'});
  await db.collection('greenhouses').doc('gh-a').set({
    'name': 'Invernadero Apizaco',
    'memberIds': ['u1', 'u2'],
    'inviteCode': 'APZ123',
  });
  await db
      .collection('greenhouses')
      .doc('gh-a')
      .collection('members')
      .doc('u1')
      .set({'role': 'operador'});
  await db.collection('greenhouses').doc('gh-c').set({
    'name': 'Ajeno',
    'memberIds': ['u9'],
    'inviteCode': 'AJENO9',
  });
  await db
      .collection('greenhouse_invites')
      .doc('AJENO9')
      .set({'greenhouseId': 'gh-c'});
}

void main() {
  late FakeFirebaseFirestore db;
  late _LiveSource live;
  late SensorDataController sensors;
  late GreenhouseSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    firebaseReady = true;
    db = FakeFirebaseFirestore();
    await _seed(db);
    live = _LiveSource();
    sensors = SensorDataController.forTesting(MockZoneStatusSource());
    session = GreenhouseSession.forTesting(
      repository: FirestoreGreenhouseRepository(firestore: db),
      sensors: sensors,
      liveSource: () => live,
    );
  });

  tearDown(() => sensors.stop());

  group('FirestoreGreenhouseRepository', () {
    test('lista solo los invernaderos del usuario, con su rol y por nombre',
        () async {
      final list =
          await FirestoreGreenhouseRepository(firestore: db).fetchForUser('u1');
      expect(list.map((g) => g.id), ['gh-a', 'gh-b']);
      expect(list.first.role, GreenhouseRole.operador);
      expect(list.last.role, GreenhouseRole.admin);
    });

    test('unirse con código agrega memberIds y el miembro como operador',
        () async {
      final repo = FirestoreGreenhouseRepository(firestore: db);
      final id = await repo.joinByCode(
          uid: 'u1', code: ' ajeno9 ', email: 'u1@gt.mx', name: 'Uno');
      expect(id, 'gh-c');
      final gh = await db.collection('greenhouses').doc('gh-c').get();
      expect(gh.data()!['memberIds'], containsAll(['u9', 'u1']));
      final member = await db
          .collection('greenhouses')
          .doc('gh-c')
          .collection('members')
          .doc('u1')
          .get();
      expect(member.data()!['role'], 'operador');
      expect(member.data()!['inviteCode'], 'AJENO9');
    });

    test('un código inexistente da un mensaje claro', () async {
      final repo = FirestoreGreenhouseRepository(firestore: db);
      expect(
        () => repo.joinByCode(uid: 'u1', code: 'NOPE'),
        throwsA(isA<GreenhouseException>()),
      );
    });
  });

  group('GreenhouseSession', () {
    test('activa el primero y se suscribe a sus sensores con la fuente real',
        () async {
      final result = await session.load('u1');
      expect(result, GreenhouseLoadResult.ready);
      expect(session.active.value!.id, 'gh-a');
      expect(sensors.source, same(live));
      expect(live.watched, ['gh-a']);
    });

    test('recuerda el último invernadero elegido', () async {
      await session.load('u1');
      await session.select(session.greenhouses.value.last);
      expect(live.watched.last, 'gh-b');

      final otra = GreenhouseSession.forTesting(
        repository: FirestoreGreenhouseRepository(firestore: db),
        sensors: sensors,
        liveSource: () => live,
      );
      await otra.load('u1');
      expect(otra.active.value!.id, 'gh-b');
    });

    test('sin invernaderos pide unirse', () async {
      expect(await session.load('nadie'), GreenhouseLoadResult.none);
      expect(session.active.value, isNull);
    });

    test('sin red usa el último invernadero guardado', () async {
      await session.load('u1');
      final offline = GreenhouseSession.forTesting(
        repository: _OfflineRepository(),
        sensors: sensors,
        liveSource: () => live,
      );
      expect(await offline.load('u1'), GreenhouseLoadResult.ready);
      expect(offline.active.value!.name, 'Invernadero Apizaco');
    });

    test('sin red y sin nada guardado devuelve error', () async {
      final offline = GreenhouseSession.forTesting(
        repository: _OfflineRepository(),
        sensors: sensors,
        liveSource: () => live,
      );
      expect(await offline.load('u1'), GreenhouseLoadResult.error);
    });

    test('el modo demo usa datos de prueba y al cerrar sesión se olvida',
        () async {
      await session.enterDemo();
      expect(session.isDemo, isTrue);
      expect(sensors.source, isA<MockZoneStatusSource>());

      await session.clear();
      expect(session.active.value, isNull);
      expect(sensors.zones.value, isEmpty);
    });
  });
}
