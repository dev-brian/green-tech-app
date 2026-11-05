# Verificación de UI en Green Tech: recetas y problemas conocidos

Lee esto cuando escribas pruebas de widget o generes capturas. Cada problema
de abajo ya costó tiempo una vez; aquí está la causa y la salida.

## Montar una pantalla a 360 px en una prueba

```dart
tester.view.devicePixelRatio = 2;
tester.view.physicalSize = const Size(360, 4000) * 2; // alto: que se construya todo
addTearDown(tester.view.reset);
await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const MiPantalla()));
await tester.pump();
await tester.pump(); // el segundo pump dibuja lo que llegó por streams/microtareas
```

Usa un alto grande cuando la pantalla es un `ListView`: los hijos fuera del
viewport no se construyen y las búsquedas (`find.text`) no los encuentran.

## Guías automáticas de accesibilidad

```dart
await expectLater(tester, meetsGuideline(androidTapTargetGuideline)); // ≥ 48 x 48
await expectLater(tester, meetsGuideline(textContrastGuideline));     // WCAG AA
```

Corren sobre todo lo que está en pantalla, así que también atrapan
problemas en widgets que no tocaste.

## Problemas conocidos

### La prueba se queda colgada al final ("did not complete")

**Causa:** `await subscription.cancel()` dentro de `testWidgets`, cuando el
`onCancel` del `StreamController` no devuelve un `Future`. El futuro que
devuelve `cancel()` está completado en la zona raíz y el reloj falso del
test nunca reanuda la continuación. Pasa con `SensorDataController.stop()`
y la fuente de prueba.

**Salida:** detén fuera del reloj falso y desmonta el árbol:

```dart
await tester.runAsync(controller.stop);
await tester.pumpWidget(const SizedBox());
```

No llames a `controller.start()` con `await` dentro del test ni lo metas en
`runAsync`: llámalo sin `await` y deja que los `pump` lo avancen. Así el
`Timer` de 5 s de la fuente de prueba vive en el reloj falso y no queda
vivo al terminar.

### Las capturas salen con cajas en lugar de letras

**Causa:** las pruebas de Flutter no tienen fuentes reales ni red, y
`google_fonts` intenta descargar Inter/Poppins.

**Salida:** `tool/screenshots/dashboard_360_test.dart` ya lo resuelve. Le da
a `google_fonts` un `assetManifest` falso que anuncia `Inter-Bold.ttf`, etc.;
responde esas peticiones de assets con Roboto del SDK
(`$FLUTTER_ROOT/bin/cache/artifacts/material_fonts`); carga
`MaterialIcons-Regular.otf` con `FontLoader`, y espera
`GoogleFonts.pendingFonts()` con `runAsync` antes de la primera captura. La
tipografía resultante es aproximada (Roboto), pero el layout es el real.

No pongas `GoogleFonts.config.allowRuntimeFetching = false`: lanza una
excepción por cada fuente y la prueba falla.

### La captura de página completa sale con mucho espacio vacío

**Causa:** `ScrollPosition.maxScrollExtent` de un `ListView` es una
estimación para los hijos que aún no se construyen.

**Salida:** renderiza alto (6000 px), suma `geometry.scrollExtent` de los
slivers del `RenderViewport` y recorta el sobrante (`_fullPageHeight` en la
herramienta).

### La herramienta de capturas marca warnings en `flutter analyze`

Vive en `tool/` (para no correr con la suite normal) y usa APIs
`@visibleForTesting`. El archivo lleva
`// ignore_for_file: invalid_use_of_visible_for_testing_member` con la
explicación; repítelo si creas otra herramienta igual.

## Generar capturas

```bash
flutter test tool/screenshots/dashboard_360_test.dart \
  --dart-define=SHOTS_DIR=docs/screenshots --dart-define=SHOTS_TAG=despues
```

Produce `dashboard-360-<tag>-{pantalla,completa,sin-conexion,sin-datos-recientes}.png`
a 2x. Para el "antes" de un rediseño, corre la misma herramienta sobre la
rama base en un worktree aparte (`git worktree add --detach <dir> <rama>`) y
ajusta lo que la base no tenga.

Para forzar situaciones usa la fuente de prueba:
`mock.setZoneScenario('zona-2', MockScenario.phAlto)`, `MockScenario.lecturaVieja`
(lectura de hace 10 min) o `controller.offline.value = true`.
