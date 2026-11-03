import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/zone_status_source.dart';

void main() {
  group('FirestoreZoneStatusSource', () {
    late FakeFirebaseFirestore db;
    late FirestoreZoneStatusSource source;

    setUp(() {
      db = FakeFirebaseFirestore();
      source = FirestoreZoneStatusSource(firestore: db);
    });

    test('emite un mapa vacío mientras el documento no existe', () async {
      final snap = await source.watchZones('gh-1').first;
      expect(snap.zones, isEmpty);
    });

    test('lee greenhouses/{id}/state/latest en tiempo real', () async {
      final doc = db.doc('greenhouses/gh-1/state/latest');
      await doc.set({
        'zona-1': {
          'ph': {'value': 6.0, 'level': 'ok'},
          'timestamp': '2026-11-03T09:00:00',
        },
      });

      final emisiones = source
          .watchZones('gh-1')
          .map((s) => s.zones['zona-1']?.ph?.level)
          .take(2)
          .toList();

      await Future<void>.delayed(Duration.zero);
      await doc.update({
        'zona-1.ph': {'value': 7.6, 'level': 'critical'},
      });

      expect(await emisiones, [EstadoNivel.normal, EstadoNivel.critico]);
    });
  });

  group('MockZoneStatusSource', () {
    MockZoneStatusSource mock({Duration interval = const Duration(seconds: 5)}) =>
        MockZoneStatusSource(interval: interval, random: Random(1));

    test('no requiere Firebase', () {
      expect(mock().requiresFirebase, isFalse);
    });

    test('emite al suscribirse con las 7 variables en ok', () async {
      final snap = await mock().watchZones('gh-1').first;

      expect(snap.fromCache, isFalse);
      expect(snap.zones.keys, ['zona-1', 'zona-2']);
      for (final zone in snap.zones.values) {
        for (final v in HydroVariable.values) {
          expect(zone[v]?.level, EstadoNivel.normal, reason: v.name);
        }
      }
    });

    test('emite de nuevo cada intervalo', () async {
      final source = mock(interval: const Duration(milliseconds: 20));
      final tres = await source.watchZones('gh-1').take(3).toList();
      expect(tres, hasLength(3));
    });

    test('el intervalo por defecto es de 5 s', () {
      expect(MockZoneStatusSource().interval, const Duration(seconds: 5));
    });

    final esperado = {
      MockScenario.phAlto: (HydroVariable.ph, EstadoNivel.critico),
      MockScenario.ecBaja: (HydroVariable.ec, EstadoNivel.alerta),
      MockScenario.tanqueBajo: (HydroVariable.tankLevel, EstadoNivel.critico),
      MockScenario.solucionCaliente:
          (HydroVariable.solutionTemp, EstadoNivel.alerta),
    };

    for (final MapEntry(key: escenario, value: (variable, nivel))
        in esperado.entries) {
      test('escenario "${escenario.label}" marca solo ${variable.name}',
          () async {
        final source = mock()..scenario = escenario;
        final zone = (await source.watchZones('gh-1').first).zones['zona-1']!;

        for (final v in HydroVariable.values) {
          expect(zone[v]?.level, v == variable ? nivel : EstadoNivel.normal,
              reason: v.name);
        }
      });
    }

    test('cambiar el escenario emite de inmediato', () async {
      final source = mock(interval: const Duration(hours: 1));
      final niveles = source
          .watchZones('gh-1')
          .map((s) => s.zones['zona-1']!.ph!.level)
          .take(2)
          .toList();

      await Future<void>.delayed(Duration.zero);
      source.scenario = MockScenario.phAlto;

      expect(await niveles, [EstadoNivel.normal, EstadoNivel.critico]);
    });
  });
}
