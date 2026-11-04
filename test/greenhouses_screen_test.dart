import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greentech_app/models/greenhouse.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/screens/greenhouse_detail_screen.dart';
import 'package:greentech_app/screens/greenhouses_screen.dart';
import 'package:greentech_app/screens/threshold_editor_screen.dart';
import 'package:greentech_app/services/greenhouse_repository.dart';
import 'package:greentech_app/utils/colors.dart';

void main() {
  final repository = GreenhouseRepository.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository.reset();
  });

  /// Monta la pantalla en un teléfono de 360 px de ancho. Es alto para que
  /// todo se construya sin desplazarse.
  Future<void> montar(WidgetTester tester, {Widget? home}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(360, 2600) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: home ?? const GreenhousesScreen(),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> escribir(WidgetTester tester, Key key, String texto) async {
    await tester.enterText(find.byKey(key), texto);
    await tester.pump();
  }

  group('Greenhouse / Crop (JSON)', () {
    test('el id se genera corto y único', () {
      expect(nuevoId(), isNotEmpty);
      expect(nuevoId(), isNot(nuevoId()));
    });

    test('round-trip conserva ubicación y umbrales', () {
      const original = Greenhouse(
        id: 'g1',
        name: 'Norte',
        location: 'Ladera este',
        crops: [
          Crop(
            id: 'c1',
            name: 'Tomate',
            thresholds: {
              HydroVariable.ph: VariableThreshold(min: 5.5, max: 6.5),
              HydroVariable.light:
                  VariableThreshold(min: 12000, max: 18000),
            },
          ),
        ],
      );

      final copia = Greenhouse.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(copia.id, 'g1');
      expect(copia.name, 'Norte');
      expect(copia.location, 'Ladera este');
      expect(copia.crops.single.name, 'Tomate');
      expect(copia.crops.single.thresholds[HydroVariable.ph]!.min, 5.5);
      expect(copia.crops.single.thresholds[HydroVariable.light]!.max, 18000);
    });

    test('una variable desconocida en el JSON se ignora', () {
      final crop = Crop.fromJson({
        'id': 'c1',
        'name': 'Tomate',
        'thresholds': {
          'variable_inventada': {'min': 1, 'max': 2},
          'ph': {'min': 5.5, 'max': 6.5},
        },
      });

      expect(crop.thresholds.keys, [HydroVariable.ph]);
    });
  });

  group('umbralTexto', () {
    test('formato con y sin unidad', () {
      expect(
        umbralTexto(
          HydroVariable.ph,
          const VariableThreshold(min: 5.5, max: 6.5),
        ),
        'pH 5.5–6.5',
      );
      expect(
        umbralTexto(
          HydroVariable.light,
          const VariableThreshold(min: 12000, max: 18000),
        ),
        'Luz 12000–18000 lux',
      );
      expect(
        umbralTexto(
          HydroVariable.airTemp,
          const VariableThreshold(min: 20, max: 26),
        ),
        'Temperatura 20.0–26.0°C',
      );
      expect(
        umbralTexto(
          HydroVariable.humidity,
          const VariableThreshold(min: 60, max: 80),
        ),
        'Humedad 60–80%',
      );
    });
  });

  group('GreenhouseRepository', () {
    test('guarda invernaderos y los vuelve a cargar', () async {
      await repository.addGreenhouse(
        const Greenhouse(id: 'g1', name: 'Norte', location: 'Ladera'),
      );
      await repository.addCrop(
        'g1',
        const Crop(
          id: 'c1',
          name: 'Tomate',
          thresholds: {
            HydroVariable.ph: VariableThreshold(min: 5.5, max: 6.5),
          },
        ),
      );

      repository.reset();
      await repository.load();

      final g = repository.greenhouseById('g1');
      expect(g, isNotNull);
      expect(g!.name, 'Norte');
      expect(g.location, 'Ladera');
      expect(g.crops.single.name, 'Tomate');
      expect(g.crops.single.thresholds[HydroVariable.ph]!.max, 6.5);
    });

    test('editar y eliminar actualizan la lista guardada', () async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await repository.addGreenhouse(const Greenhouse(id: 'g2', name: 'Sur'));
      await repository.updateGreenhouse(
        const Greenhouse(id: 'g1', name: 'Norte 2'),
      );
      await repository.deleteGreenhouse('g2');

      repository.reset();
      await repository.load();

      expect(repository.greenhouses.value, hasLength(1));
      expect(repository.greenhouses.value.single.name, 'Norte 2');
    });
  });

  group('Invernaderos a 360 px', () {
    testWidgets('estado vacío invita a crear el primero', (tester) async {
      await montar(tester);

      expect(find.text('Invernaderos'), findsOneWidget);
      expect(find.text('Aún no tienes invernaderos'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('greenhouse_name')), findsOneWidget);

      // Sin nombre no se guarda.
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pump();
      expect(find.text('Ingresa un nombre'), findsOneWidget);
      expect(repository.greenhouses.value, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('greenhouse_name')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('agrega un invernadero con nombre y ubicación',
        (tester) async {
      await montar(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await escribir(tester, const Key('greenhouse_name'), 'Invernadero Norte');
      await escribir(tester, const Key('greenhouse_location'), 'Ladera este');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Invernadero Norte'), findsOneWidget);
      expect(find.text('Ladera este · 0 cultivos'), findsOneWidget);
      expect(repository.greenhouses.value.single.name, 'Invernadero Norte');
      expect(tester.takeException(), isNull);
    });

    testWidgets('edita un invernadero existente', (tester) async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await montar(tester);

      await tester.tap(find.byTooltip('Editar invernadero Norte'));
      await tester.pumpAndSettle();
      expect(find.text('Editar invernadero'), findsOneWidget);

      await escribir(tester, const Key('greenhouse_name'), 'Sur');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Sur'), findsOneWidget);
      expect(find.text('Norte'), findsNothing);
      expect(repository.greenhouses.value.single.name, 'Sur');
      expect(tester.takeException(), isNull);
    });

    testWidgets('elimina solo con confirmación', (tester) async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await montar(tester);

      await tester.tap(find.byTooltip('Eliminar invernadero Norte'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar invernadero?'), findsOneWidget);
      expect(find.textContaining('junto con sus cultivos'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Norte'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar invernadero Norte'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Norte'), findsNothing);
      expect(repository.greenhouses.value, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toques ≥ 48 px y contraste AA', (tester) async {
      await repository.addGreenhouse(
        const Greenhouse(id: 'g1', name: 'Norte', location: 'Ladera este'),
      );
      await repository.addCrop(
        'g1',
        const Crop(
          id: 'c1',
          name: 'Tomate',
          thresholds: {
            HydroVariable.ph: VariableThreshold(min: 5.5, max: 6.5),
          },
        ),
      );
      await montar(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(tester.takeException(), isNull);
    });
  });

  group('Detalle y umbrales a 360 px', () {
    testWidgets('abre el detalle y agrega un cultivo', (tester) async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await montar(tester);

      await tester.tap(find.byKey(const Key('greenhouse_g1')));
      await tester.pumpAndSettle();
      expect(find.byType(GreenhouseDetailScreen), findsOneWidget);
      expect(find.text('Este invernadero no tiene cultivos'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await escribir(tester, const Key('crop_name'), 'Tomate');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Tomate'), findsOneWidget);
      expect(find.text('Sin umbrales configurados'), findsOneWidget);
      expect(repository.greenhouses.value.single.crops.single.name, 'Tomate');
      expect(tester.takeException(), isNull);
    });

    testWidgets('configura umbrales de pH y luz de un cultivo',
        (tester) async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await repository.addCrop(
        'g1',
        const Crop(id: 'c1', name: 'Tomate'),
      );
      await montar(
        tester,
        home: const GreenhouseDetailScreen(greenhouseId: 'g1'),
      );

      await tester.tap(find.byKey(const Key('crop_c1')));
      await tester.pumpAndSettle();
      expect(find.byType(ThresholdEditorScreen), findsOneWidget);

      await escribir(tester, const Key('umbral_min_ph'), '5.5');
      await escribir(tester, const Key('umbral_max_ph'), '6.5');
      await escribir(tester, const Key('umbral_min_light'), '12000');
      await escribir(tester, const Key('umbral_max_light'), '18000');
      await tester.tap(find.byTooltip('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.byType(ThresholdEditorScreen), findsNothing);
      expect(find.text('pH 5.5–6.5'), findsOneWidget);
      expect(find.text('Luz 12000–18000 lux'), findsOneWidget);

      final crop = repository.greenhouses.value.single.crops.single;
      expect(crop.thresholds[HydroVariable.ph]!.min, 5.5);
      expect(crop.thresholds[HydroVariable.light]!.max, 18000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el mínimo no puede superar al máximo', (tester) async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await repository.addCrop('g1', const Crop(id: 'c1', name: 'Tomate'));
      await montar(
        tester,
        home: const GreenhouseDetailScreen(greenhouseId: 'g1'),
      );

      await tester.tap(find.byKey(const Key('crop_c1')));
      await tester.pumpAndSettle();

      await escribir(tester, const Key('umbral_min_ph'), '7');
      await escribir(tester, const Key('umbral_max_ph'), '5.5');
      await tester.tap(find.byTooltip('Guardar cambios'));
      await tester.pump();

      expect(
        find.text('El mínimo no puede superar al máximo'),
        findsWidgets,
      );
      expect(find.byType(ThresholdEditorScreen), findsOneWidget);
      expect(
        repository.greenhouses.value.single.crops.single.thresholds,
        isEmpty,
      );
    });

    testWidgets('toques ≥ 48 px y contraste AA en detalle y umbrales',
        (tester) async {
      await repository.addGreenhouse(const Greenhouse(id: 'g1', name: 'Norte'));
      await repository.addCrop(
        'g1',
        const Crop(
          id: 'c1',
          name: 'Tomate',
          thresholds: {
            HydroVariable.ph: VariableThreshold(min: 5.5, max: 6.5),
            HydroVariable.humidity:
                VariableThreshold(min: 60, max: 80),
          },
        ),
      );
      await montar(
        tester,
        home: const GreenhouseDetailScreen(greenhouseId: 'g1'),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(find.byKey(const Key('crop_c1')));
      await tester.pumpAndSettle();
      expect(find.byType(ThresholdEditorScreen), findsOneWidget);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(tester.takeException(), isNull);
    });
  });
}
