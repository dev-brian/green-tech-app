// Capturas del Detalle con chips de zona a 360 px de ancho (teléfono Android pequeño).
//
// No corre con `flutter test` normal (vive fuera de test/). Para generarlas:
//
//   flutter test tool/screenshots/detalle_chips_360_test.dart \
//     --dart-define=SHOTS_DIR=docs/screenshots --dart-define=SHOTS_TAG=despues
//
// Las pruebas de Flutter no cargan fuentes reales: aquí se sirven Roboto y
// MaterialIcons del SDK (Roboto ocupa el lugar de Plus Jakarta Sans), así que la
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
import 'package:greentech_app/screens/sensor_detail_screen.dart';
import 'package:greentech_app/services/data_sources.dart';
import 'package:greentech_app/services/greenhouse_session.dart';
import 'package:greentech_app/widgets/zone_selector.dart';
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
        for (final family in ['Inter', 'Poppins', 'PlusJakartaSans'])
          for (final peso in _roboto.keys) 'fonts/$family-$peso.ttf',
      ];

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

/// Responde las peticiones de esos assets con los bytes de Roboto del SDK.
void _serveFonts(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
      (message) async {
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
  final viewport =
      tester.renderObject<RenderViewport>(find.byType(Viewport).first);
  var content = 0.0;
  for (RenderSliver? s = viewport.firstChild;
      s != null;
      s = viewport.childAfter(s)) {
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
    final file = File('$_dir/detalle-chips-360-$_tag-$name.png')
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

  Future<void> render(WidgetTester tester, [double height = _height]) async {
    tester.view.devicePixelRatio = _pixelRatio;
    tester.view.physicalSize = Size(_width, height) * _pixelRatio;
    await tester.pump();
    await tester.pump();
  }

  Widget app(GlobalKey key, {bool dark = false}) => RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? buildDarkAppTheme() : buildAppTheme(),
          home: const SensorDetailScreen(),
        ),
      );

  Finder chip(String id) =>
      find.descendant(of: find.byType(ZoneSelector), matching: find.text(id));

  testWidgets('capturas del Detalle con chips a 360 px', (tester) async {
    _serveFonts(tester);
    final key = GlobalKey();
    final session = GreenhouseSession.instance;
    final mock = MockZoneStatusSource(interval: const Duration(hours: 1))
      ..setZoneScenario('zona-2', MockScenario.phAlto);
    await tester.runAsync(
        () => session.startDemo(sources: DataSources.demo(mock: mock)));

    await tester.pumpWidget(app(key));
    await render(tester);
    await tester.runAsync(GoogleFonts.pendingFonts);
    await render(tester);
    await _capture(tester, key, 'zona-1');

    await tester.tap(chip('zona-2'));
    await render(tester);
    // Deja terminar la animación de selección y el ripple del chip.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, 'zona-2');

    await tester.pumpWidget(app(key, dark: true));
    await render(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, key, 'oscuro');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(session.clear);
  });

  testWidgets('8 zonas, la elegida al final de la lista', (tester) async {
    _serveFonts(tester);
    final key = GlobalKey();
    final session = GreenhouseSession.instance;
    final mock = MockZoneStatusSource(
      interval: const Duration(hours: 1),
      zoneIds: [for (var i = 1; i <= 8; i++) 'zona-$i'],
    );
    await tester.runAsync(
        () => session.startDemo(sources: DataSources.demo(mock: mock)));
    // Como si se hubiera abierto el Detalle de zona-8 desde el Dashboard.
    SensorDataController.instance.selectZone('zona-8');

    await tester.pumpWidget(app(key));
    await render(tester);
    await tester.runAsync(GoogleFonts.pendingFonts);
    await render(tester);
    await _capture(tester, key, 'muchas-zonas');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(session.clear);
  });
}
