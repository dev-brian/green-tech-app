import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/config/variable_config.dart';
import 'package:greentech_app/models/zone_status.dart';

void main() {
  group('variableSpecs (tabla única de configuración)', () {
    test('tiene una entrada por cada variable', () {
      expect(variableSpecs.keys.toSet(), HydroVariable.values.toSet());
    });

    test('Ambiente: temperatura, humedad y luz', () {
      expect(variablesOf(VariableGroup.ambiente), [
        HydroVariable.airTemp,
        HydroVariable.humidity,
        HydroVariable.light,
      ]);
    });

    test('Solución nutritiva: pH, EC, temperatura de la solución y tanque', () {
      expect(variablesOf(VariableGroup.solucion), [
        HydroVariable.ph,
        HydroVariable.ec,
        HydroVariable.solutionTemp,
        HydroVariable.tankLevel,
      ]);
    });

    test('unidades y decimales', () {
      expect(HydroVariable.airTemp.spec.unit, '°C');
      expect(HydroVariable.humidity.spec.unit, '%');
      expect(HydroVariable.light.spec.unit, 'lux');
      expect(HydroVariable.ph.spec.unit, '');
      expect(HydroVariable.ec.spec.unit, 'mS/cm');
      expect(HydroVariable.solutionTemp.spec.unit, '°C');
      expect(HydroVariable.tankLevel.spec.unit, '%');
      expect(HydroVariable.ec.spec.decimals, 2);
    });
  });

  group('VariableSpec.display', () {
    test('formatea cada unidad', () {
      expect(HydroVariable.airTemp.spec.display(22.46), '22.5°C');
      expect(HydroVariable.tankLevel.spec.display(78.4), '78%');
      expect(HydroVariable.ec.spec.display(1.8), '1.80 mS/cm');
      expect(HydroVariable.light.spec.display(18000), '18000 lux');
      expect(HydroVariable.ph.spec.display(6.04), '6.0');
    });
  });
}
