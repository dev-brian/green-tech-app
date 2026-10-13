import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/models/sensor_model.dart';
import 'package:greentech_app/widgets/live_clock.dart';
import 'package:greentech_app/widgets/sensor_card.dart';

/// 155 x 145 ≈ tamaño real de cada tarjeta en el grid del Dashboard en un
/// teléfono (2 columnas, mainAxisExtent 145).
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 155, height: 145, child: child),
        ),
      ),
    );

void main() {
  group('SensorCard (semáforo)', () {
    testWidgets('muestra valor, unidad y etiqueta del estado', (tester) async {
      await tester.pumpWidget(_wrap(const SensorCard(
        label: 'Temperatura',
        value: '35.0',
        unit: '°C',
        icon: Icons.thermostat,
        estado: EstadoNivel.critico,
      )));

      expect(find.text('35.0'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
      expect(find.text('Crítico'), findsOneWidget);
    });

    testWidgets('con datos desactualizados apaga el semáforo', (tester) async {
      await tester.pumpWidget(_wrap(const SensorCard(
        label: 'Temperatura',
        value: '24.5',
        unit: '°C',
        icon: Icons.thermostat,
        estado: EstadoNivel.normal,
        desactualizado: true,
      )));

      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.text('Normal'), findsNothing);
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
