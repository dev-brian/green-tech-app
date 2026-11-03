import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/screens/dashboard_screen.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/widgets/sensor_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('con la fuente de prueba muestra las 7 variables y sus zonas',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final controller = SensorDataController.instance;
    expect(controller.source, isA<MockZoneStatusSource>());
    final mock = controller.source as MockZoneStatusSource;

    // Todo corre en el reloj falso del test: el Timer de 5 s de la fuente
    // de prueba no avanza solo, así que no hay timers vivos al terminar.
    controller.start();
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SensorCard), findsNWidgets(HydroVariable.values.length));
    for (final v in HydroVariable.values) {
      expect(find.text(v.label), findsOneWidget, reason: v.name);
    }
    expect(find.widgetWithText(ChoiceChip, 'zona-1'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'zona-2'), findsOneWidget);
    expect(find.text('Crítico'), findsNothing);

    // El evento del stream llega como microtarea: un pump la entrega y el
    // siguiente dibuja el frame con el nuevo nivel.
    mock.scenario = MockScenario.tanqueBajo;
    await tester.pump();
    await tester.pump();
    expect(find.text('Crítico'), findsOneWidget);

    // Fuera del reloj falso: `await subscription.cancel()` no se reanuda
    // dentro de testWidgets cuando onCancel no devuelve un Future.
    await tester.runAsync(controller.stop);
    mock.scenario = MockScenario.normal;
    await tester.pumpWidget(const SizedBox());
  });
}
