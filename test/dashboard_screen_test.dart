import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/screens/dashboard_screen.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/utils/colors.dart';
import 'package:greentech_app/widgets/variable_card.dart';
import 'package:greentech_app/widgets/zone_section.dart';

ZoneStatus _zona(String id, EstadoNivel nivel, {Duration edad = Duration.zero}) =>
    ZoneStatus(
      zoneId: id,
      timestamp: DateTime(2026, 11, 3, 12).subtract(edad),
      ph: Measurement(value: 6.0, level: nivel),
    );

void main() {
  group('zonasPorSeveridad', () {
    final now = DateTime(2026, 11, 3, 12);

    test('crítico, sin datos recientes, alerta y normal; empate por id', () {
      final orden = zonasPorSeveridad([
        _zona('a-normal', EstadoNivel.normal),
        _zona('b-alerta', EstadoNivel.alerta),
        _zona('c-vieja', EstadoNivel.normal,
            edad: const Duration(minutes: 10)),
        _zona('e-critica', EstadoNivel.critico),
        _zona('d-critica', EstadoNivel.critico),
      ], now);

      expect(orden.map((z) => z.zoneId),
          ['d-critica', 'e-critica', 'c-vieja', 'b-alerta', 'a-normal']);
    });
  });

  group('DashboardScreen a 360 px', () {
    late SensorDataController controller;
    late MockZoneStatusSource mock;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = SensorDataController.instance;
      mock = controller.source as MockZoneStatusSource;
    });

    /// Monta el Dashboard en un teléfono de 360 px de ancho. Es alto para
    /// que se construyan todas las zonas sin desplazarse.
    Future<void> montar(WidgetTester tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(360, 4000) * 2;
      addTearDown(tester.view.reset);
      // Todo corre en el reloj falso del test: el Timer de 5 s de la fuente
      // de prueba no avanza solo, así que no hay timers vivos al terminar.
      controller.start();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const DashboardScreen(),
      ));
      await tester.pump();
      await tester.pump();
    }

    Future<void> desmontar(WidgetTester tester) async {
      // Fuera del reloj falso: `await subscription.cancel()` no se reanuda
      // dentro de testWidgets cuando onCancel no devuelve un Future.
      await tester.runAsync(controller.stop);
      mock.scenario = MockScenario.normal;
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('una sección por zona, la peor primero, con sus dos grupos',
        (tester) async {
      mock.setZoneScenario('zona-1', MockScenario.ecBaja);
      mock.setZoneScenario('zona-2', MockScenario.tanqueBajo);
      await montar(tester);

      final secciones = tester
          .widgetList<ZoneSection>(find.byType(ZoneSection))
          .map((s) => s.zone.zoneId);
      expect(secciones, ['zona-2', 'zona-1']);

      expect(find.byType(VariableCard),
          findsNWidgets(2 * HydroVariable.values.length));
      expect(find.text('AMBIENTE'), findsNWidgets(2));
      expect(find.text('SOLUCIÓN NUTRITIVA'), findsNWidgets(2));
      // Estado general: crítico en el resumen, en zona-2 y en su tarjeta.
      expect(find.text('Crítico'), findsNWidgets(3));
      expect(find.text('2 de 2 zonas requieren atención'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });

    testWidgets('una zona que dejó de reportar se muestra en gris',
        (tester) async {
      mock.setZoneScenario('zona-2', MockScenario.lecturaVieja);
      await montar(tester);

      final secciones = tester
          .widgetList<ZoneSection>(find.byType(ZoneSection))
          .map((s) => s.zone.zoneId);
      expect(secciones, ['zona-2', 'zona-1']);
      // 7 tarjetas + el encabezado de la zona + el resumen.
      expect(find.text('Sin datos recientes'),
          findsNWidgets(HydroVariable.values.length + 2));
      expect(find.text('Hace 10 min'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('avisa "Sin conexión · datos de las HH:MM"', (tester) async {
      await montar(tester);
      expect(find.textContaining('Sin conexión'), findsNothing);

      controller.offline.value = true;
      await tester.pump();
      final hora = DateFormat('HH:mm')
          .format(controller.zones.value.values.first.timestamp);
      expect(find.text('Sin conexión · datos de las $hora'), findsOneWidget);

      controller.offline.value = false;
      await desmontar(tester);
    });

    testWidgets('toques ≥ 48 px y contraste AA', (tester) async {
      mock.setZoneScenario('zona-1', MockScenario.solucionCaliente);
      mock.setZoneScenario('zona-2', MockScenario.phAlto);
      await montar(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await desmontar(tester);
    });
  });
}
