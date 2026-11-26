import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/screens/sensor_detail_screen.dart';
import 'package:greentech_app/services/data_sources.dart';
import 'package:greentech_app/services/greenhouse_session.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/services/zone_status_source.dart';
import 'package:greentech_app/utils/colors.dart';
import 'package:greentech_app/widgets/zone_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fuente controlable: cada [emitir] manda las zonas indicadas.
class _FakeZones implements ZoneStatusSource {
  final _ctrl = StreamController<ZoneStatusSnapshot>.broadcast();

  @override
  bool get requiresFirebase => false;

  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) => _ctrl.stream;

  void emitir(List<String> ids) => _ctrl.add(ZoneStatusSnapshot(
        zones: {for (final id in ids) id: _zona(id)},
        fromCache: false,
      ));
}

ZoneStatus _zona(String id) => ZoneStatus(
      zoneId: id,
      timestamp: DateTime.now(),
      ph: const Measurement(value: 6.0, level: EstadoNivel.normal),
    );

Map<String, ZoneStatus> _zonas(List<String> ids) =>
    {for (final id in ids) id: _zona(id)};

void _a360(WidgetTester tester, {double alto = 800}) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(360, alto) * 2;
  addTearDown(tester.view.reset);
}

/// Chips de zona (el histórico también usa ChoiceChip).
final _chips = find.descendant(
    of: find.byType(ZoneSelector), matching: find.byType(ChoiceChip));

Finder _chip(String id) =>
    find.descendant(of: _chips, matching: find.text(id)).first;

bool _seleccionado(WidgetTester tester, String id) => tester
    .widget<ChoiceChip>(
        find.ancestor(of: _chip(id), matching: find.byType(ChoiceChip)))
    .selected;

Future<void> _montarSelector(
  WidgetTester tester, {
  required List<String> ids,
  required String seleccionado,
  ValueChanged<String>? onSelected,
  bool oscuro = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    darkTheme: buildDarkAppTheme(),
    themeMode: oscuro ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      backgroundColor: oscuro ? AppColors.darkBackground : AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ZoneSelector(
          zones: _zonas(ids),
          selectedId: seleccionado,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  ));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ZoneSelector (widget suelto)', () {
    testWidgets('con una sola zona no se muestra', (tester) async {
      _a360(tester);
      await _montarSelector(tester, ids: ['zona-1'], seleccionado: 'zona-1');
      expect(_chips, findsNothing);
    });

    testWidgets('sin zonas no se muestra ni truena', (tester) async {
      _a360(tester);
      await _montarSelector(tester, ids: [], seleccionado: 'zona-1');
      expect(_chips, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('marca la zona seleccionada y avisa al tocar otra',
        (tester) async {
      _a360(tester);
      final tocadas = <String>[];
      await _montarSelector(tester,
          ids: ['zona-2', 'zona-1', 'zona-3'],
          seleccionado: 'zona-2',
          onSelected: tocadas.add);

      expect(_chips, findsNWidgets(3));
      expect(_seleccionado(tester, 'zona-2'), isTrue);
      expect(_seleccionado(tester, 'zona-1'), isFalse);

      await tester.tap(_chip('zona-3'));
      // Tocar la zona ya seleccionada no debe deseleccionarla ni fallar.
      await tester.tap(_chip('zona-2'));
      expect(tocadas, ['zona-3', 'zona-2']);
    });

    testWidgets('ordena las zonas alfabéticamente', (tester) async {
      _a360(tester);
      await _montarSelector(tester,
          ids: ['zona-b', 'zona-c', 'zona-a'], seleccionado: 'zona-a');
      final xs = [
        for (final id in ['zona-a', 'zona-b', 'zona-c'])
          tester.getTopLeft(_chip(id)).dx
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    testWidgets('12 zonas a 360 px: sin desborde y con scroll horizontal',
        (tester) async {
      _a360(tester);
      final ids = [
        for (var i = 1; i <= 12; i++) 'zona-${'$i'.padLeft(2, '0')}'
      ];
      await _montarSelector(tester, ids: ids, seleccionado: 'zona-01');
      expect(tester.takeException(), isNull);

      // La última no cabe al principio (ni se construye); se alcanza deslizando.
      expect(find.text('zona-12'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(-3000, 0));
      await tester.pumpAndSettle();
      // Al final del scroll, la última queda completa dentro del padding.
      expect(tester.getTopRight(_chip('zona-12')).dx, lessThanOrEqualTo(344));
    });

    testWidgets('nombre de zona largo no desborda', (tester) async {
      _a360(tester);
      await _montarSelector(tester,
          ids: ['Invernadero norte - lechuga hidropónica fila 3', 'zona-2'],
          seleccionado: 'zona-2');
      expect(tester.takeException(), isNull);
    });

    for (final oscuro in [false, true]) {
      testWidgets(
          'toques de 48 px y contraste AA (${oscuro ? 'oscuro' : 'claro'})',
          (tester) async {
        _a360(tester);
        await _montarSelector(tester,
            ids: ['zona-1', 'zona-2'], seleccionado: 'zona-1', oscuro: oscuro);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  });

  group('Chips en el Detalle (modo demo)', () {
    late MockZoneStatusSource mock;
    final controller = SensorDataController.instance;
    final session = GreenhouseSession.instance;

    Future<void> montar(WidgetTester tester) async {
      _a360(tester, alto: 3200);
      mock = MockZoneStatusSource(interval: const Duration(hours: 1))
        ..setZoneScenario('zona-2', MockScenario.phAlto);
      await tester.runAsync(
          () => session.startDemo(sources: DataSources.demo(mock: mock)));
      await tester.pump();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: const SensorDetailScreen(),
      ));
      await tester.pump();
      await tester.pump();
    }

    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(session.clear);
    }

    String encabezado(WidgetTester tester) =>
        controller.currentZone.value!.zoneId;

    testWidgets('tocar un chip cambia zona, lecturas y actuadores',
        (tester) async {
      await montar(tester);
      expect(encabezado(tester), 'zona-1');
      expect(_seleccionado(tester, 'zona-1'), isTrue);
      // zona-1 normal: pH no crítico, dosificador apagado.
      final encendidosZona1 = find.text('Encendido').evaluate().length;

      await tester.tap(_chip('zona-2'));
      await tester.pump();
      await tester.pump();

      expect(encabezado(tester), 'zona-2');
      expect(_seleccionado(tester, 'zona-2'), isTrue);
      expect(_seleccionado(tester, 'zona-1'), isFalse);
      // El encabezado "Zona" de la tarjeta muestra la nueva zona.
      expect(find.text('zona-2'), findsNWidgets(2)); // chip + encabezado
      // phAlto en zona-2: el dosificador de pH se enciende.
      expect(find.text('Encendido').evaluate().length,
          greaterThan(encendidosZona1));
      expect(tester.takeException(), isNull);

      // Y de vuelta a zona-1.
      await tester.tap(_chip('zona-1'));
      await tester.pump();
      await tester.pump();
      expect(encabezado(tester), 'zona-1');
      expect(find.text('Encendido').evaluate().length, encendidosZona1);

      await desmontar(tester);
    });

    testWidgets('la zona elegida se mantiene cuando llega una lectura nueva',
        (tester) async {
      await montar(tester);
      await tester.tap(_chip('zona-2'));
      await tester.pump();

      mock.setZoneScenario('zona-1', MockScenario.tanqueBajo); // emite
      await tester.pump();
      await tester.pump();

      expect(encabezado(tester), 'zona-2');
      expect(_seleccionado(tester, 'zona-2'), isTrue);
      await desmontar(tester);
    });

    testWidgets('pull-to-refresh no pierde la zona elegida', (tester) async {
      await montar(tester);
      await tester.tap(_chip('zona-2'));
      await tester.pump();

      await tester.runAsync(controller.start);
      await tester.pump();
      await tester.pump();
      expect(encabezado(tester), 'zona-2');
      await desmontar(tester);
    });

    testWidgets('si la zona elegida desaparece, cae a la primera',
        (tester) async {
      await montar(tester);
      final fake = _FakeZones();
      controller.useSource(fake);
      // start() cancela la suscripción anterior; fuera del reloj falso.
      await tester.runAsync(controller.start);
      await tester.pump();
      fake.emitir(['zona-1', 'zona-2', 'zona-3']);
      await tester.pump();
      await tester.pump();

      await tester.tap(_chip('zona-3'));
      await tester.pump();
      expect(encabezado(tester), 'zona-3');

      fake.emitir(['zona-1', 'zona-2']);
      await tester.pump();
      await tester.pump();
      expect(encabezado(tester), 'zona-1');
      expect(_chips, findsNWidgets(2));
      expect(_seleccionado(tester, 'zona-1'), isTrue);

      // Si queda una sola zona, los chips se ocultan.
      fake.emitir(['zona-2']);
      await tester.pump();
      await tester.pump();
      expect(encabezado(tester), 'zona-2');
      expect(_chips, findsNothing);
      expect(tester.takeException(), isNull);
      await desmontar(tester);
    });

    testWidgets('Detalle a 360 px con chips: toques y contraste',
        (tester) async {
      await montar(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await desmontar(tester);
    });
  });
}
