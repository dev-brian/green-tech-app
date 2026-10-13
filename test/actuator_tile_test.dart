import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/actuator_model.dart';
import 'package:greentech_app/widgets/actuator_tile.dart';

final _now = DateTime(2026, 10, 12, 12, 0);

Actuador _bomba({required bool encendido}) => Actuador(
      id: 'bomba-01',
      nombre: 'Bomba de riego',
      tipo: TipoActuador.bomba,
      encendido: encendido,
      actualizado: _now.subtract(const Duration(minutes: 2)),
    );

/// 328 px ≈ ancho útil del Dashboard en un teléfono de 360 dp.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 328, child: child),
        ),
      ),
    );

BoxDecoration _ledDecoration(WidgetTester tester) {
  final led = tester.widget<AnimatedContainer>(find.descendant(
      of: find.byType(StatusLed), matching: find.byType(AnimatedContainer)));
  return led.decoration! as BoxDecoration;
}

void main() {
  testWidgets('encendido: LED verde con brillo y switch activo', (tester) async {
    await tester.pumpWidget(
        _wrap(ActuatorTile(actuador: _bomba(encendido: true), now: _now)));
    await tester.pumpAndSettle();

    expect(find.text('Bomba de riego'), findsOneWidget);
    expect(find.text('Encendido · hace 2 min'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(_ledDecoration(tester).color, StatusLed.colorEncendido);
    expect(_ledDecoration(tester).boxShadow, isNotEmpty);
    expect(find.byIcon(Icons.water), findsOneWidget);
  });

  testWidgets('apagado: LED gris sin brillo y switch apagado', (tester) async {
    await tester.pumpWidget(
        _wrap(ActuatorTile(actuador: _bomba(encendido: false), now: _now)));
    await tester.pumpAndSettle();

    expect(find.text('Apagado · hace 2 min'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(_ledDecoration(tester).color, isNot(StatusLed.colorEncendido));
    expect(_ledDecoration(tester).boxShadow, isEmpty);
  });

  testWidgets('el switch es solo lectura: tocarlo no cambia nada',
      (tester) async {
    await tester.pumpWidget(
        _wrap(ActuatorTile(actuador: _bomba(encendido: false), now: _now)));
    await tester.tap(find.byType(Switch), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('expone el estado a lectores de pantalla', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
        _wrap(ActuatorTile(actuador: _bomba(encendido: true), now: _now)));

    expect(find.bySemanticsLabel('Bomba de riego: Encendido'), findsOneWidget);
    handle.dispose();
  });
}
