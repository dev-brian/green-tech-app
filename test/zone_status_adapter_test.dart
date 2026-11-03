import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/adapters/zone_status_adapter.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';

/// Entrada completa de una zona tal como la escribe el backend.
Map<String, dynamic> _entrada({Object? timestamp}) => {
      'airTemp': {'value': 22.5, 'level': 'ok'},
      'humidity': {'value': 65, 'level': 'ok'},
      'light': {'value': 18000, 'level': 'ok'},
      'ph': {'value': 7.6, 'level': 'critical'},
      'ec': {'value': 0.8, 'level': 'warn'},
      'solutionTemp': {'value': 20.5, 'level': 'ok'},
      'tankLevel': {'value': 78, 'level': 'ok'},
      'timestamp': timestamp ?? Timestamp.fromDate(DateTime.utc(2026, 11, 3, 9)),
    };

void main() {
  group('ZoneStatusAdapter.fromFirestore', () {
    test('lee las 7 variables con su value y level', () {
      final z = ZoneStatusAdapter.fromFirestore('zona-1', _entrada());

      expect(z.zoneId, 'zona-1');
      expect(z.timestamp.toUtc(), DateTime.utc(2026, 11, 3, 9));
      expect(z.airTemp, const Measurement(value: 22.5, level: EstadoNivel.normal));
      expect(z.humidity?.value, 65.0);
      expect(z.light?.value, 18000.0);
      expect(z.ph, const Measurement(value: 7.6, level: EstadoNivel.critico));
      expect(z.ec, const Measurement(value: 0.8, level: EstadoNivel.alerta));
      expect(z.solutionTemp?.value, 20.5);
      expect(z.tankLevel?.value, 78.0);
      for (final v in HydroVariable.values) {
        expect(z[v], isNotNull, reason: v.name);
      }
    });

    test('ZoneStatus.fromFirestore (Factory Method) delega en el adaptador', () {
      final entrada = _entrada();
      final z = ZoneStatus.fromFirestore('zona-1', entrada);
      final a = ZoneStatusAdapter.fromFirestore('zona-1', entrada);
      for (final v in HydroVariable.values) {
        expect(z[v], a[v], reason: v.name);
      }
    });

    test('usa el level del backend, no rangos propios', () {
      // pH 6.0 es un valor sano, pero si el backend dice "critical", manda.
      final z = ZoneStatusAdapter.fromFirestore('zona-1', {
        'ph': {'value': 6.0, 'level': 'critical'},
        'tankLevel': {'value': 5, 'level': 'ok'},
      });
      expect(z.ph?.level, EstadoNivel.critico);
      expect(z.tankLevel?.level, EstadoNivel.normal);
      expect(z.overallLevel, EstadoNivel.critico);
    });

    test('una variable ausente o mal formada queda en null', () {
      final z = ZoneStatusAdapter.fromFirestore('zona-1', {
        'airTemp': {'value': 22.5, 'level': 'ok'},
        'humidity': {'value': '65', 'level': 'ok'}, // value no numérico
        'light': {'value': 18000}, // sin level
        'ph': {'value': 6.0, 'level': 'danger'}, // level desconocido
        'ec': 1.8, // no es un mapa
        // solutionTemp y tankLevel no vienen
      });

      expect(z.airTemp, isNotNull);
      for (final v in HydroVariable.values.skip(1)) {
        expect(z[v], isNull, reason: v.name);
      }
      expect(z.overallLevel, EstadoNivel.normal);
    });

    test('acepta timestamp ISO 8601 y usa "ahora" si falta', () {
      final iso = ZoneStatusAdapter.fromFirestore(
          'zona-1', _entrada(timestamp: '2026-11-03T10:30:00'));
      expect(iso.timestamp, DateTime(2026, 11, 3, 10, 30));

      final antes = DateTime.now();
      final sinFecha = ZoneStatusAdapter.fromFirestore('zona-1', const {});
      expect(sinFecha.timestamp.isBefore(antes), isFalse);
    });
  });

  group('ZoneStatusAdapter.zonesFromDocument', () {
    test('crea una zona por cada entrada del documento', () {
      final zonas = ZoneStatusAdapter.zonesFromDocument({
        'zona-1': _entrada(),
        'zona-2': _entrada(),
        'updatedBy': 'backend', // campo que no es una zona: se ignora
      });

      expect(zonas.keys, unorderedEquals(['zona-1', 'zona-2']));
      expect(zonas['zona-2']?.zoneId, 'zona-2');
    });
  });

  group('ZoneStatusAdapter.toFirestore', () {
    test('ida y vuelta conserva los valores y niveles', () {
      final original = ZoneStatusAdapter.fromFirestore('zona-1', _entrada());
      final json = ZoneStatusAdapter.toFirestore(original);

      expect(json['ph'], {'value': 7.6, 'level': 'critical'});
      expect(json['ec'], {'value': 0.8, 'level': 'warn'});
      expect(json['timestamp'], isA<String>());

      final copia = ZoneStatusAdapter.fromFirestore('zona-1', json);
      for (final v in HydroVariable.values) {
        expect(copia[v], original[v], reason: v.name);
      }
      expect(copia.timestamp, original.timestamp);
    });

    test('omite las variables que no llegaron', () {
      final json = ZoneStatusAdapter.toFirestore(ZoneStatus(
        zoneId: 'zona-1',
        timestamp: DateTime(2026, 11, 3),
        ph: const Measurement(value: 6.0, level: EstadoNivel.normal),
      ));
      expect(json.keys, unorderedEquals(['ph', 'timestamp']));
    });
  });
}
