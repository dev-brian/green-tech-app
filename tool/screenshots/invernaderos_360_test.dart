// Capturas de los invernaderos y los umbrales en solo lectura a 360 px.
//
//   flutter test tool/screenshots/invernaderos_360_test.dart \
//     --dart-define=SHOTS_DIR=docs/screenshots
//
// Vive fuera de test/ para no correr con la suite normal. Lee fuentes del SDK
// como tool/screenshots/dashboard_360_test.dart (el layout es el real).
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts;
import 'package:greentech_app/adapters/threshold_adapter.dart';
import 'package:greentech_app/models/crop_thresholds.dart';
import 'package:greentech_app/models/greenhouse.dart';
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

const _dir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots');
const _width = 360.0;
const _pixelRatio = 2.0;

String get _sdkFonts =>
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';

const _roboto = {
  'Thin': 'Roboto-Thin.ttf',
  'ExtraLight': 'Roboto-Thin.ttf',
  'Light': 'Roboto-Light.ttf',
  'Regular': 'Roboto-Regular.ttf',
  'Medium': 'Roboto-Medium.ttf',
  'SemiBold': 'Roboto-Bold.ttf',
  'Bold': 'Roboto-Bold.ttf',
  'ExtraBold': 'Roboto-Black.ttf',
  'Black': 'Roboto-Black.ttf',
};

class _FontsManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
        for (final family in ['Inter', 'Poppins', 'PlusJakartaSans'])
          for (final peso in _roboto.keys) 'fonts/$family-$peso.ttf',
      ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void _serveFonts(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    final match = RegExp(r'^fonts/\w+-(\w+)\.ttf$').firstMatch(key);
    final file = match == null ? null : _roboto[match.group(1)];
    if (file == null) return null;
    final bytes = File('$_sdkFonts/$file').readAsBytesSync();
    return ByteData.view(bytes.buffer);
  });
}

Future<void> _loadIcons() async {
  final bytes = File('$_sdkFonts/MaterialIcons-Regular.otf').readAsBytesSync();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer))))
      .load();
}

class _FakeGreenhouses implements GreenhouseRepository {
  _FakeGreenhouses({this.lista = const []});

  List<Greenhouse> lista = [];
  Map<String, dynamic> datos = const {};

  @override
  Future<List<Greenhouse>> myGreenhouses(String uid) async => lista;

  @override
  Future<String> joinWithCode({
    required String code,
    required String uid,
    String? email,
    String? name,
  }) =>
      throw UnimplementedError();

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

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  double height = 780,
}) async {
  tester.view.physicalSize = Size(_width, height) * _pixelRatio;
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_dir/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    google_fonts.assetManifest = _FontsManifest();
    await _loadIcons();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebaseReady = true;
  });

  testWidgets('capturas de invernaderos y umbrales a 360 px', (tester) async {
    _serveFonts(tester);
    final key = GlobalKey();
    const norte = Greenhouse(
      id: 'g1',
      name: 'Invernadero Norte',
      role: GreenhouseRole.admin,
    );
    const sur = Greenhouse(
      id: 'g2',
      name: 'Invernadero Sur',
      role: GreenhouseRole.operador,
    );
    final repo = _FakeGreenhouses(lista: const [norte, sur])
      ..datos = {
        'thresholdsByCrop': {
          'jitomate': {'ec': {'yellowMin': 2.2, 'yellowMax': 3.6}},
        },
      };
    final session = GreenhouseSession.forTesting(
      repository: repo,
      sensors: SensorDataController.forTesting(_FakeZones()),
      alerts: AlertsController.forTesting(_FakeAlerts(), notify: (_) {}),
      currentUid: () => 'uid-1',
    );
    session.greenhouses.value = const [norte, sur];
    session.current.value = norte;

    Future<void> render(Widget pantalla) async {
      tester.view.devicePixelRatio = _pixelRatio;
      tester.view.physicalSize = const Size(_width, 780) * _pixelRatio;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: pantalla,
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(GoogleFonts.pendingFonts);
      await tester.pump();
    }

    await render(GreenhousesScreen(session: session, repository: repo));
    await _capture(tester, key, 'invernaderos-360-lista');

    session.greenhouses.value = const [];
    session.current.value = null;
    await render(GreenhousesScreen(session: session, repository: repo));
    await _capture(tester, key, 'invernaderos-360-vacio');

    session.greenhouses.value = const [norte, sur];
    session.current.value = norte;
    await render(GreenhouseDetailScreen(
      greenhouse: norte,
      session: session,
      repository: repo,
    ));
    await _capture(tester, key, 'invernaderos-360-detalle-umbrales');

    final umbrales = ThresholdAdapter.fromFirestore(repo.datos);
    await render(CropThresholdsScreen(
      greenhouse: norte,
      umbrales: umbrales[CropType.jitomate]!,
    ));
    await _capture(tester, key, 'umbrales-360-lector', height: 2600);

    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}
