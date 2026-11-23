import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/crop_thresholds.dart';
import 'package:greentech_app/models/greenhouse.dart';
import 'package:greentech_app/repositories/greenhouse_repository.dart';
import 'package:greentech_app/services/account_deletion.dart';

class _Repo implements GreenhouseRepository {
  _Repo(this.lista);
  List<Greenhouse> lista;
  final salidas = <String>[];

  @override
  Future<List<Greenhouse>> myGreenhouses(String uid) async => lista;

  @override
  Future<String> joinWithCode(
          {required String code,
          required String uid,
          String? email,
          String? name}) =>
      throw UnimplementedError();

  @override
  Future<void> leave(
          {required String greenhouseId, required String uid}) async =>
      salidas.add(greenhouseId);

  @override
  Future<Map<CropType, CropThresholds>> thresholds(
    String greenhouseId,
  ) async =>
      const {};
}

void main() {
  late List<String> pasos;

  AccountDeletion crear(_Repo repo, {int segundos = 30}) => AccountDeletion(
        uid: 'uid-1',
        greenhouses: repo,
        secondsSinceSignIn: () async => segundos,
        unregisterPush: () async => pasos.add('push'),
        deleteAuthUser: () async => pasos.add('auth'),
        clearLocalData: () async => pasos.add('local'),
      );

  setUp(() => pasos = []);

  test('operador: borra push, sale de cada invernadero y luego la cuenta',
      () async {
    final repo = _Repo(const [
      Greenhouse(id: 'a', name: 'A', role: GreenhouseRole.operador),
      Greenhouse(id: 'b', name: 'B', role: GreenhouseRole.operador),
    ]);
    await crear(repo).run();
    expect(repo.salidas, ['a', 'b']);
    expect(pasos, ['push', 'auth', 'local']);
  });

  test('administrador: no borra nada y explica qué hacer', () async {
    final repo = _Repo(const [
      Greenhouse(id: 'a', name: 'Norte', role: GreenhouseRole.admin),
    ]);
    await expectLater(
      crear(repo).run(),
      throwsA(isA<AccountDeletionException>()
          .having((e) => e.code, 'code', 'is-admin')
          .having((e) => e.message, 'message', contains('Norte'))),
    );
    expect(repo.salidas, isEmpty);
    expect(pasos, isEmpty);
  });

  test('sesión vieja: pide volver a entrar antes de borrar', () async {
    final repo = _Repo(const [
      Greenhouse(id: 'a', name: 'A', role: GreenhouseRole.operador),
    ]);
    await expectLater(
      crear(repo, segundos: 3600).run(),
      throwsA(isA<AccountDeletionException>()
          .having((e) => e.code, 'code', 'requires-recent-login')),
    );
    expect(repo.salidas, isEmpty);
    expect(pasos, isEmpty);
  });
}
