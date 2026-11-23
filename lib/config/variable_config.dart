import 'package:flutter/material.dart';

import '../models/zone_status.dart';

/// Grupos de tarjetas dentro de cada zona del Dashboard.
enum VariableGroup {
  ambiente('Ambiente', Icons.park_outlined),
  solucion('Solución nutritiva', Icons.water_drop_outlined);

  const VariableGroup(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Cómo se presenta una variable en la app.
class VariableSpec {
  const VariableSpec({
    required this.label,
    required this.unit,
    required this.icon,
    required this.decimals,
    required this.group,
  });

  final String label;
  final String unit;
  final IconData icon;

  /// Decimales con los que se muestra el valor.
  final int decimals;
  final VariableGroup group;

  String format(double value) => value.toStringAsFixed(decimals);

  /// Valor con su unidad, p. ej. `22.5°C`, `65%`, `1.80 mS/cm` o `6.0`.
  /// °C y % van pegados al número; las demás unidades, separadas.
  String display(double value) {
    if (unit.isEmpty) return format(value);
    final pegada = unit == '°C' || unit == '%';
    return pegada ? '${format(value)}$unit' : '${format(value)} $unit';
  }
}

/// ÚNICA tabla de presentación de las variables: nombre, unidad, ícono,
/// decimales y grupo. Para agregar o cambiar una variable en la UI se
/// edita solo esta tabla. El orden de las entradas es el orden en pantalla.
const Map<HydroVariable, VariableSpec> variableSpecs = {
  HydroVariable.airTemp: VariableSpec(
    label: 'Temperatura',
    unit: '°C',
    icon: Icons.thermostat,
    decimals: 1,
    group: VariableGroup.ambiente,
  ),
  HydroVariable.humidity: VariableSpec(
    label: 'Humedad',
    unit: '%',
    icon: Icons.water_drop_outlined,
    decimals: 0,
    group: VariableGroup.ambiente,
  ),
  HydroVariable.light: VariableSpec(
    label: 'Luz',
    unit: 'lux',
    icon: Icons.wb_sunny_outlined,
    decimals: 0,
    group: VariableGroup.ambiente,
  ),
  HydroVariable.ph: VariableSpec(
    label: 'pH',
    unit: '',
    icon: Icons.science_outlined,
    decimals: 1,
    group: VariableGroup.solucion,
  ),
  HydroVariable.ec: VariableSpec(
    label: 'EC',
    unit: 'mS/cm',
    icon: Icons.bolt_outlined,
    decimals: 2,
    group: VariableGroup.solucion,
  ),
  HydroVariable.solutionTemp: VariableSpec(
    label: 'Temp. de la solución',
    unit: '°C',
    icon: Icons.device_thermostat,
    decimals: 1,
    group: VariableGroup.solucion,
  ),
  HydroVariable.tankLevel: VariableSpec(
    label: 'Nivel del tanque',
    unit: '%',
    icon: Icons.propane_tank_outlined,
    decimals: 0,
    group: VariableGroup.solucion,
  ),
};

extension HydroVariableSpec on HydroVariable {
  VariableSpec get spec => variableSpecs[this]!;
}

/// Variables de [group], en el orden de la tabla.
List<HydroVariable> variablesOf(VariableGroup group) => [
      for (final MapEntry(key: v, value: spec) in variableSpecs.entries)
        if (spec.group == group) v,
    ];
