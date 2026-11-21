import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/push_alert.dart';
import 'package:greentech_app/repositories/fcm_token_repository.dart';
import 'package:greentech_app/services/push_service.dart';

class FakeMessaging implements PushMessaging {
  String? tokenActual = 'tok-1';
  bool permiso = true;
  int borrados = 0;
  PushAlert? inicial;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushAlert>.broadcast();
  final opened = StreamController<PushAlert>.broadcast();

  @override
  Future<bool> requestPermission() async => permiso;
  @override
  Future<String?> getToken() async => tokenActual;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<void> deleteToken() async => borrados++;
  @override
  Stream<PushAlert> get onForeground => foreground.stream;
  @override
  Stream<PushAlert> get onOpened => opened.stream;
  @override
  Future<PushAlert?> initialOpened() async => inicial;
}

const _alerta = PushAlert(
    greenhouseId: 'gh-1', alertId: 'a-1', title: 'pH alto', body: 'Zona 1');

void main() {
  group('PushAlert.fromMessage', () {
    test('toma título y texto del bloque notification', () {
      final a = PushAlert.fromMessage({
        'greenhouseId': 'gh-1',
        'alertId': 'a-9',
        'zoneId': 'zona-1',
        'variable': 'ph',
        'severity': 'warn',
      }, title: 'pH alto', body: 'Zona 1: 7.4');
      expect(a.greenhouseId, 'gh-1');
      expect(a.alertId, 'a-9');
      expect(a.variable, 'ph');
      expect(a.critica, isFalse);
      expect(a.title, 'pH alto');
      expect(a.body, 'Zona 1: 7.4');
    });

    test('mensaje solo data: usa message y por defecto es crítica', () {
      final a = PushAlert.fromMessage({'message': 'Tanque bajo', 'zoneId': ''});
      expect(a.critica, isTrue);
      expect(a.title, contains('crítica'));
      expect(a.body, 'Tanque bajo');
      expect(a.zoneId, isNull);
    });
  });

  group('FirestoreFcmTokenRepository', () {
    test('guarda users/{uid}/fcmTokens/{token} y lo borra', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreFcmTokenRepository(firestore: db);
      await repo.save('uid-1', 'tok-1');
      final doc = await db
          .collection('users')
          .doc('uid-1')
          .collection('fcmTokens')
          .doc('tok-1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['token'], 'tok-1');
      expect(doc.data()!['platform'], 'android');
      expect(doc.data()!.containsKey('createdAt'), isTrue);
      expect(doc.data()!.containsKey('lastSeenAt'), isTrue);

      // Volver a registrar no duplica.
      await repo.save('uid-1', 'tok-1');
      final todos = await db
          .collection('users')
          .doc('uid-1')
          .collection('fcmTokens')
          .get();
      expect(todos.docs, hasLength(1));

      await repo.remove('uid-1', 'tok-1');
      expect(
          (await db
                  .collection('users')
                  .doc('uid-1')
                  .collection('fcmTokens')
                  .get())
              .docs,
          isEmpty);
    });
  });

  group('PushService', () {
    late FakeMessaging fm;
    late FakeFirebaseFirestore db;
    late PushService push;
    late StreamController<String?> uid;
    late List<PushAlert> mostradas;
    String? escuchando;

    Future<List<String>> tokens(String u) async =>
        (await db.collection('users').doc(u).collection('fcmTokens').get())
            .docs
            .map((d) => d.id)
            .toList();

    setUp(() async {
      fm = FakeMessaging();
      db = FakeFirebaseFirestore();
      push = PushService.forTesting(
          fm, FirestoreFcmTokenRepository(firestore: db));
      uid = StreamController<String?>();
      mostradas = [];
      escuchando = null;
    });

    tearDown(() => push.dispose());

    Future<void> iniciar() => push.init(
          uidChanges: uid.stream,
          bandejaEscucha: (gh) => gh != null && gh == escuchando,
          mostrar: (a) async => mostradas.add(a),
        );

    test('al iniciar sesión registra el token del celular', () async {
      await iniciar();
      uid.add('uid-1');
      await pumpEventQueue();
      expect(await tokens('uid-1'), ['tok-1']);
      expect(push.token, 'tok-1');
    });

    test('si FCM renueva el token, cambia el documento', () async {
      await iniciar();
      uid.add('uid-1');
      await pumpEventQueue();
      fm.refresh.add('tok-2');
      await pumpEventQueue();
      expect(await tokens('uid-1'), ['tok-2']);
    });

    test('unregister borra el token antes de cerrar sesión', () async {
      await iniciar();
      uid.add('uid-1');
      await pumpEventQueue();
      await push.unregister();
      expect(await tokens('uid-1'), isEmpty);
      expect(fm.borrados, 1);
      expect(push.token, isNull);
    });

    test('permiso negado: lo informa y aun así guarda el token', () async {
      fm.permiso = false;
      await iniciar();
      uid.add('uid-1');
      await pumpEventQueue();
      expect(push.permitido.value, isFalse);
      expect(await tokens('uid-1'), ['tok-1']);
    });

    test('sin token (sin Play Services) no escribe nada', () async {
      fm.tokenActual = null;
      await iniciar();
      uid.add('uid-1');
      await pumpEventQueue();
      expect(await tokens('uid-1'), isEmpty);
    });

    test('en primer plano muestra el push si la bandeja no lo ve', () async {
      await iniciar();
      fm.foreground.add(_alerta);
      await pumpEventQueue();
      expect(mostradas, [_alerta]);
    });

    test('en primer plano no repite lo que la bandeja ya avisa', () async {
      escuchando = 'gh-1';
      await iniciar();
      fm.foreground.add(_alerta);
      await pumpEventQueue();
      expect(mostradas, isEmpty);
    });

    test('tocar la notificación pide abrir la bandeja', () async {
      await iniciar();
      fm.opened.add(_alerta);
      await pumpEventQueue();
      expect(push.openAlerts.value, _alerta);
    });

    test('la app abierta desde una notificación también la abre', () async {
      fm.inicial = _alerta;
      await iniciar();
      expect(push.openAlerts.value, _alerta);
    });
  });
}
