import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/models/zone_status.dart';
import 'package:greentech_app/utils/colors.dart';
import 'package:greentech_app/widgets/live_clock.dart';
import 'package:greentech_app/widgets/variable_card.dart';

/// 158 px ≈ ancho real de cada tarjeta a 360 px (2 columnas).
Widget _wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 158, child: child),
        ),
      ),
    );

void main() {
  group('VariableCard', () {
    testWidgets('muestra nombre, valor, unidad y estado con ícono y texto',
        (tester) async {
      await tester.pumpWidget(_wrap(const VariableCard(
        variable: HydroVariable.ph,
        measurement: Measurement(value: 7.62, level: EstadoNivel.critico),
      )));

      expect(find.text('pH'), findsOneWidget);
      expect(find.text('7.6'), findsOneWidget);
      expect(find.text('Crítico'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el texto de estado usa el color AA del semáforo',
        (tester) async {
      await tester.pumpWidget(_wrap(const VariableCard(
        variable: HydroVariable.ec,
        measurement: Measurement(value: 0.8, level: EstadoNivel.alerta),
      )));

      final estado = tester.widget<Text>(find.text('Alerta'));
      expect(estado.style?.color,
          AppColors.estadoTexto(EstadoNivel.alerta, isDark: false));
      expect(find.text('mS/cm'), findsOneWidget);
    });

    testWidgets('con lectura vieja pasa a gris y dice "Sin datos recientes"',
        (tester) async {
      await tester.pumpWidget(_wrap(const VariableCard(
        variable: HydroVariable.airTemp,
        measurement: Measurement(value: 24.5, level: EstadoNivel.critico),
        desactualizada: true,
      )));

      expect(find.text('Sin datos recientes'), findsOneWidget);
      expect(find.text('Crítico'), findsNothing);
      final estado = tester.widget<Text>(find.text('Sin datos recientes'));
      expect(estado.style?.color, AppColors.sinDatos(isDark: false));
    });

    testWidgets('sin la variable muestra "—" y "Sin datos"', (tester) async {
      await tester.pumpWidget(_wrap(const VariableCard(
        variable: HydroVariable.tankLevel,
        measurement: null,
      )));

      expect(find.text('—'), findsOneWidget);
      expect(find.text('Sin datos'), findsOneWidget);
    });

    testWidgets('el objetivo táctil mide al menos 48 x 48', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(VariableCard(
        variable: HydroVariable.light,
        measurement:
            const Measurement(value: 18000, level: EstadoNivel.normal),
        onTap: () => taps++,
      )));

      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(VariableCard));
      expect(taps, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets('cumple contraste de texto WCAG AA', (tester) async {
      await tester.pumpWidget(_wrap(const VariableCard(
        variable: HydroVariable.solutionTemp,
        measurement: Measurement(value: 27.5, level: EstadoNivel.alerta),
      )));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });

  group('formatHace / lecturaDesactualizada', () {
    final now = DateTime(2026, 10, 12, 12, 0, 0);

    test('textos relativos', () {
      expect(formatHace(now.subtract(const Duration(seconds: 2)), now),
          'Justo ahora');
      expect(formatHace(now.subtract(const Duration(seconds: 40)), now),
          'Hace 40 seg');
      expect(formatHace(now.subtract(const Duration(minutes: 7)), now),
          'Hace 7 min');
      expect(formatHace(DateTime(2026, 10, 11, 9, 5), now), '11/10 09:05');
    });

    test('una lectura de más de 5 min se considera desactualizada', () {
      expect(lecturaDesactualizada(now.subtract(const Duration(minutes: 4)), now),
          isFalse);
      expect(lecturaDesactualizada(now.subtract(const Duration(minutes: 6)), now),
          isTrue);
    });
  });
}
