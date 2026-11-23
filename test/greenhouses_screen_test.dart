import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/adapters/threshold_adapter.dart';
import 'package:greentech_app/models/crop_thresholds.dart';
import 'package:greentech_app/models/greenhouse.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/repositories/alerts_repository.dart';
import 'package:greentech_app/repositories/greenhouse_repository.dart';
import 'package:greentech_app/screens/crop_thresholds_screen.dart';
import 'package:greentech_app/screens/greenhouse_detail_screen.dart';
import 'package:greentech_app/screens/greenhouses_screen.dart';
import 'package:greentech_app/services/alerts_controller.dart';
import 'package:greentech_app/services/app_status.dart';
import 'package:greentech_app/services/greenhouse_session.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/services/zone_status_source.dart';
import 'package:greentech_app/utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGreenhouses implements GreenhouseRepository {
  _FakeGreenhouses({this.lista = const []});

  List<Greenhouse> lista;
  Map<String, dynamic> datos = const {};

  @override
  Future<List<Greenhouse>> myGreenhouses(String uid) async => lista;

  @override
  Future<String> joinWithCode({
    required String code,
    required String uid,
    String? email,
    String? name,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> leave({
    required String greenhouseId,
    required String uid,
  }) async {}

  @override
  Future<Map<CropType, CropThresholds>> thresholds(
    String greenhouseId,
  ) async =>
      ThresholdAdapter.fromFirestore(datos);
}

class _FakeZones implements ZoneStatusSource {
  @override
  bool get requiresFirebase => true;

  @override
  Stream<ZoneStatusSnapshot> watchZones(String greenhouseId) =>
      const Stream.empty();
}

class _FakeAlerts implements AlertsRepository {
  @override
  Stream<AlertsSnapshot> watch(String greenhouseId) => const Stream.empty();

  @override
  Future<void> attend(String g, String a, String u) async {}
}

void main() {
  const norte = Greenhouse(id: 'g1', name: 'Invernadero Norte', role: GreenhouseRole.admin);
  const sur = Greenhouse(id: 'g2', name: 'Invernadero Sur', role: GreenhouseRole.operador);

  late _FakeGreenhouses repo;
  late GreenhouseSession session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebaseReady = true;
    repo = _FakeGreenhouses(lista: const [norte, sur]);
    session = GreenhouseSession.forTesting(
      repository: repo,
      sensors: SensorDataController.forTesting(_FakeZones()),
      alerts: AlertsController.forTesting(_FakeAlerts(), notify: (_) {}),
      currentUid: () => 'uid-1',
    );
    session.greenhouses.value = const [norte, sur];
    session.current.value = norte;
  });

  /// Monta la pantalla en un teléfono de 360 px de ancho.
  Future<void> montar(WidgetTester tester, Widget pantalla) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(360, 2600) * 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: pantalla,
    ));
    await tester.pump();
    await tester.pump();
  }

  Widget lista() =>
      GreenhousesScreen(session: session, repository: repo);

  Widget detalle() => GreenhouseDetailScreen(
        greenhouse: norte,
        session: session,
        repository: repo,
      );

  group('Umbrales reales de Firestore', () {
    test('sin datos guardados se muestran los perfiles por defecto', () {
      final umbrales = ThresholdAdapter.fromFirestore({});
      expect(umbrales[CropType.jitomate]!.de(HydroVariable.ph)!.yellowMin, 5.5);
      expect(umbrales[CropType.lechuga]!.de(HydroVariable.ec)!.yellowMax, 1.2);
      expect(umbrales[CropType.jitomate]!.personalizadas, isEmpty);
    });

    test('thresholdsByCrop solo afecta al cultivo indicado', () {
      final umbrales = ThresholdAdapter.fromFirestore({
        'thresholdsByCrop': {
          'lechuga': {'ec': {'redMin': 0.6, 'yellowMin': 1.0, 'yellowMax': 1.4, 'redMax': 1.8}},
        },
      });
      expect(umbrales[CropType.lechuga]!.de(HydroVariable.ec)!.yellowMin, 1.0);
      expect(
        umbrales[CropType.lechuga]!.personalizadas,
        contains(HydroVariable.ec),
      );
      expect(umbrales[CropType.jitomate]!.de(HydroVariable.ec)!.yellowMin, 2.0);
    });

    test('el campo viejo thresholds solo aplica a jitomate', () {
      final umbrales = ThresholdAdapter.fromFirestore({
        'thresholds': {'ec': {'yellowMin': 2.5}},
      });
      expect(umbrales[CropType.jitomate]!.de(HydroVariable.ec)!.yellowMin, 2.5);
      expect(umbrales[CropType.jitomate]!.de(HydroVariable.ec)!.redMin, 1.5);
      expect(umbrales[CropType.lechuga]!.de(HydroVariable.ec)!.yellowMin, 0.8);
    });
  });

  group('Invernaderos a 360 px (solo lectura)', () {
    testWidgets('lista los invernaderos reales con su rol y sin controles de alta o borrado',
        (tester) async {
      await montar(tester, lista());

      expect(find.text('Invernadero Norte'), findsOneWidget);
      expect(find.text('Invernadero Sur'), findsOneWidget);
      expect(find.textContaining('Administrador · En uso'), findsOneWidget);
      expect(find.text('Operador'), findsOneWidget);
      expect(find.byKey(const Key('greenhouse_g1')), findsOneWidget);
      expect(find.text('Agregar invernadero'), findsNothing);
      expect(find.byTooltip(RegExp(r'^Eliminar')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('estado vacío invita a unirse con código', (tester) async {
      repo.lista = const [];
      session.greenhouses.value = const [];
      session.current.value = null;

      await montar(tester, lista());

      expect(find.text('Aún no tienes invernaderos'), findsOneWidget);
      expect(find.byKey(const Key('unirse_con_codigo')), findsOneWidget);
    });

    testWidgets('abre el detalle con los cultivos y los umbrales efectivos',
        (tester) async {
      repo.datos = {
        'thresholdsByCrop': {
          'jitomate': {'ph': {'yellowMin': 5.6, 'yellowMax': 6.6}},
        },
      };
      await montar(tester, detalle());

      expect(find.text('Jitomate'), findsOneWidget);
      expect(find.text('Lechuga'), findsOneWidget);
      expect(find.textContaining('1 variable ajustada'), findsOneWidget);
      expect(
        find.textContaining('consultan aquí y se gestionan en la PWA'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('crop_jitomate')));
      await tester.pumpAndSettle();

      expect(find.byType(CropThresholdsScreen), findsOneWidget);
      expect(find.byKey(const Key('umbral_precaucion_ph')), findsOneWidget);
      expect(find.textContaining('5.6'), findsOneWidget);
      expect(find.text('Valor personalizado'), findsWidgets);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('pasa las guías de accesibilidad a 360 px', (tester) async {
      await montar(tester, lista());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('el detalle pasa las guías de accesibilidad a 360 px',
        (tester) async {
      await montar(tester, detalle());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
