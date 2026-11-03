import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/actuator_model.dart';
import 'package:greentech_app/services/telemetry_repository.dart';

void main() {
  group('Actuador.fromFirestore', () {
    test('lee un documento completo', () {
      final ts = DateTime.utc(2026, 10, 12, 14, 17, 31);
      final a = Actuador.fromFirestore('bomba-01', {
        'nombre': 'Bomba de riego',
        'tipo': 'bomba',
        'sensor_id': 'ESP32-01',
        'greenhouseId': 'axtR6p9ocsE0L79H5wbN',
        'encendido': true,
        'actualizado': Timestamp.fromDate(ts),
      });

      expect(a.id, 'bomba-01');
      expect(a.tipo, TipoActuador.bomba);
      expect(a.encendido, isTrue);
      expect(a.greenhouseId, 'axtR6p9ocsE0L79H5wbN');
      expect(a.actualizado!.toUtc(), ts);
    });

    test('valores faltantes o desconocidos no truenan', () {
      final a = Actuador.fromFirestore(
          'x-9', {'tipo': 'Ventilador ', 'encendido': 'si'});
      expect(a.nombre, 'x-9');
      expect(a.tipo, TipoActuador.ventilador);
      expect(a.encendido, isFalse);
      expect(a.actualizado, isNull);

      expect(Actuador.fromFirestore('y', {'tipo': 'nebulizador'}).tipo,
          TipoActuador.otro);
    });
  });

  test('watchActuators filtra por sensor, ordena y emite cambios en vivo',
      () async {
    final db = FakeFirebaseFirestore();
    final col = db.collection('actuadores');
    await col.doc('vent-01').set({
      'nombre': 'Ventilador',
      'tipo': 'ventilador',
      'sensor_id': 'ESP32-01',
      'encendido': false
    });
    await col.doc('bomba-01').set({
      'nombre': 'Bomba de riego',
      'tipo': 'bomba',
      'sensor_id': 'ESP32-01',
      'encendido': true
    });
    await col.doc('otra-01').set({
      'nombre': 'Luz',
      'tipo': 'luz',
      'sensor_id': 'ESP32-02',
      'encendido': true
    });

    final repo = FirestoreTelemetryRepository(firestore: db);
    final emisiones = repo
        .watchActuators('ESP32-01')
        .map((l) => l.map((a) => '${a.id}:${a.encendido}').toList())
        .take(2)
        .toList();

    await Future<void>.delayed(Duration.zero);
    await col.doc('vent-01').update({'encendido': true});

    expect(await emisiones, [
      ['bomba-01:true', 'vent-01:false'],
      ['bomba-01:true', 'vent-01:true'],
    ]);
  });
}
