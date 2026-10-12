import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/services/telemetry_repository.dart';

void main() {
  group('SensorReading.fromFirestore', () {
    test('lee un documento completo con Timestamp', () {
      final ts = DateTime.utc(2026, 10, 12, 14, 13, 47);
      final r = SensorReading.fromFirestore('ESP32-01', {
        'sensor_id': 'ESP32-01',
        'ubicacion': 'Zona Tomate A',
        'greenhouseId': 'axtR6p9ocsE0L79H5wbN',
        'temperatura': 24.5,
        'humedad_aire': 65,
        'humedad_suelo': 70,
        'timestamp': Timestamp.fromDate(ts),
      });

      expect(r.sensorId, 'ESP32-01');
      expect(r.greenhouseId, 'axtR6p9ocsE0L79H5wbN');
      expect(r.temperatura, 24.5);
      expect(r.humedadAire, 65.0);
      expect(r.timestamp.toUtc(), ts);
      expect(r.estadoGeneral, EstadoNivel.normal);
    });

    test('usa el id del documento si falta sensor_id y acepta fecha ISO', () {
      final r = SensorReading.fromFirestore('ESP32-07', {
        'temperatura': 33,
        'humedad_aire': 65,
        'humedad_suelo': 70,
        'timestamp': '2026-10-12T10:30:00',
      });

      expect(r.sensorId, 'ESP32-07');
      expect(r.ubicacion, '');
      expect(r.greenhouseId, isNull);
      expect(r.timestamp, DateTime(2026, 10, 12, 10, 30));
      expect(r.estadoTemperatura, EstadoNivel.critico);
    });
  });

  group('FirestoreTelemetryRepository', () {
    late FakeFirebaseFirestore db;
    late FirestoreTelemetryRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirestoreTelemetryRepository(firestore: db);
    });

    test('emite null mientras el documento no existe', () async {
      final snap = await repo.watchReading('ESP32-01').first;
      expect(snap.reading, isNull);
    });

    test('emite cada cambio del documento en tiempo real', () async {
      final doc = db.collection('telemetria').doc('ESP32-01');
      await doc.set({
        'temperatura': 24.5,
        'humedad_aire': 65,
        'humedad_suelo': 70,
        'timestamp': Timestamp.now(),
      });

      final emisiones = repo
          .watchReading('ESP32-01')
          .map((s) => s.reading?.temperatura)
          .take(2)
          .toList();

      await Future<void>.delayed(Duration.zero);
      await doc.update({'temperatura': 31.0});

      expect(await emisiones, [24.5, 31.0]);
    });
  });
}
