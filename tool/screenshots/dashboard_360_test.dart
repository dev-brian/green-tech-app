// Capturas del Dashboard a 360 px de ancho (teléfono Android pequeño).
//
// No corre con `flutter test` normal (vive fuera de test/). Para generarlas:
//
//   flutter test tool/screenshots/dashboard_360_test.dart \
//     --dart-define=SHOTS_DIR=docs/screenshots --dart-define=SHOTS_TAG=despues
//
// Las pruebas de Flutter no cargan fuentes reales: aquí se sirven Roboto y
// MaterialIcons del SDK (Roboto ocupa el lugar de Inter/Poppins), así que la
// tipografía de la captura es aproximada pero el layout es el real.
//
// Es una prueba de Flutter aunque viva fuera de test/ (para no correr con la
// suite normal), así que usa APIs @visibleForTesting igual que las pruebas.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts;
import 'package:greentech_app/screens/dashboard_screen.dart';
import 'package:greentech_app/services/api_service.dart';
import 'package:greentech_app/services/mock_zone_status_source.dart';
import 'package:greentech_app/services/sensor_data_controller.dart';
import 'package:greentech_app/utils/colors.dart';

const _dir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots');
const _tag = String.fromEnvironment('SHOTS_TAG', defaultValue: 'captura');
const _width = 360.0;
const _height = 780.0;
const _pixelRatio = 2.0;

String get _sdkFonts =>
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';

/// Variante de Roboto que ocupa el lugar de cada peso de Inter/Poppins.
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

/// Manifiesto falso: le dice a google_fonts que "Inter-Bold.ttf", etc.
/// vienen en los assets, para que no intente bajarlas de internet.
class _FontsManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
        for (final family in ['Inter', 'Poppins'])
          for (final peso in _roboto.keys) 'fonts/$family-$peso.ttf',
      ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

/// Responde las peticiones de esos assets con los bytes de Roboto del SDK.
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

/// Alto que necesita la página para mostrarse completa. Se mide con todo
/// construido (ListView estima el alto de los hijos que aún no construye).
Future<double> _fullPageHeight(WidgetTester tester) async {
  const tall = 6000.0;
  tester.view.physicalSize = const Size(_width, tall) * _pixelRatio;
  await tester.pump();
  final viewport = tester.renderObject<RenderViewport>(find.byType(Viewport).first);
  var content = 0.0;
  for (RenderSliver? s = viewport.firstChild; s != null; s = viewport.childAfter(s)) {
    content += s.geometry!.scrollExtent;
  }
  return tall - (viewport.size.height - content);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name,
    {bool fullPage = false}) async {
  if (fullPage) {
    final height = await _fullPageHeight(tester);
    tester.view.physicalSize = Size(_width, height) * _pixelRatio;
    await tester.pump();
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_dir/dashboard-360-$_tag-$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    google_fonts.assetManifest = _FontsManifest();
    await _loadIcons();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('capturas del Dashboard a 360 px', (tester) async {
    _serveFonts(tester);
    final key = GlobalKey();
    final controller = SensorDataController.instance;
    final mock = controller.source as MockZoneStatusSource;
    // zona-1 en alerta y zona-2 en crítico: la crítica debe salir primero.
    mock.setZoneScenario('zona-1', MockScenario.solucionCaliente);
    mock.setZoneScenario('zona-2', MockScenario.phAlto);

    Future<void> render(double height) async {
      tester.view.devicePixelRatio = _pixelRatio;
      tester.view.physicalSize = Size(_width, height) * _pixelRatio;
      await tester.pump();
      await tester.pump();
    }

    controller.start();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const DashboardScreen(),
      ),
    ));
    await render(_height);
    controller.weatherError.value = null;
    controller.weather.value = CurrentWeather(
      location: 'Tlaxcala',
      temperature: 19.4,
      humidity: 58,
      timestamp: DateTime.now(),
    );
    // google_fonts carga sus fuentes de forma asíncrona: hay que esperarlas
    // con el reloj real antes de la primera captura.
    await tester.runAsync(GoogleFonts.pendingFonts);
    await render(_height);
    await _capture(tester, key, 'pantalla');

    await _capture(tester, key, 'completa', fullPage: true);

    controller.offline.value = true;
    await render(_height);
    await _capture(tester, key, 'sin-conexion');
    controller.offline.value = false;

    mock.scenario = MockScenario.normal;
    mock.setZoneScenario('zona-1', MockScenario.lecturaVieja);
    await render(_height);
    await _capture(tester, key, 'sin-datos-recientes');

    await tester.runAsync(controller.stop);
    mock.scenario = MockScenario.normal;
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  });
}
