import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/screens/sensor_detail_screen.dart';
import 'package:greentech_app/services/greenhouse_session.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/data_sources.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/utils/colors.dart';
import 'package:greentech_app/widgets/actuators_card.dart';
import 'package:greentech_app/widgets/history_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Detalle a 360 px: actuadores e histórico (modo demo)',
      (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(360, 3200) * 2;
    addTearDown(tester.view.reset);

    final mock = MockZoneStatusSource(interval: const Duration(hours: 1))
      ..setZoneScenario('zona-1', MockScenario.phAlto);
    final session = GreenhouseSession.instance;
    await tester.runAsync(
        () => session.startDemo(sources: DataSources.demo(mock: mock)));
    await tester.pump();
    SensorDataController.instance.selectZone('zona-1');

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const SensorDetailScreen(),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ActuatorsCard), findsOneWidget);
    expect(find.text('Dosificador de pH'), findsOneWidget);
    // phAlto: el dosificador de pH está encendido.
    expect(find.text('Encendido'), findsNWidgets(2));

    expect(find.byType(HistorySection), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    await tester.tap(find.text('7 d'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(LineChart), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('historico_tankLevel')));
    await tester.tap(find.byKey(const Key('historico_tankLevel')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(session.clear);
  });
}
