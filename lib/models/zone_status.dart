import '../adapters/zone_status_adapter.dart';
import 'sensor_model.dart';

/// Las 7 variables hidropónicas que reporta cada zona del invernadero.
///
/// El orden de los valores es el orden en que se muestran en la app.
enum HydroVariable {
  airTemp('Temperatura del aire', '°C', 1),
  humidity('Humedad ambiental', '%', 0),
  light('Luz', 'lux', 0),
  ph('pH', '', 1),
  ec('Conductividad (EC)', 'mS/cm', 2),
  solutionTemp('Temperatura de la solución', '°C', 1),
  tankLevel('Nivel del tanque', '%', 0);

  const HydroVariable(this.label, this.unit, this.decimals);

  final String label;
  final String unit;

  /// Decimales con los que se muestra el valor.
  final int decimals;

  String format(double value) => value.toStringAsFixed(decimals);

  /// Valor con su unidad, p. ej. `22.5°C`, `65%`, `1.80 mS/cm` o `6.0`.
  String display(double value) => switch (unit) {
        '' => format(value),
        '°C' || '%' => '${format(value)}$unit',
        _ => '${format(value)} $unit',
      };
}

/// Una variable medida: su valor y el nivel que calculó el backend.
///
/// La app no decide si un valor es bueno o malo; solo pinta [level].
class Measurement {
  final double value;
  final EstadoNivel level;

  const Measurement({required this.value, required this.level});

  @override
  bool operator ==(Object other) =>
      other is Measurement && other.value == value && other.level == level;

  @override
  int get hashCode => Object.hash(value, level);
}

/// Estado de una zona del invernadero: una entrada de
/// `greenhouses/{id}/state/latest` (ver docs/firestore-contract.md).
///
/// Cada variable es null si el backend no la mandó o vino mal formada; la
/// UI la muestra como "Sin datos" en lugar de suponer que está bien.
class ZoneStatus {
  final String zoneId;
  final Measurement? airTemp;
  final Measurement? humidity;
  final Measurement? light;
  final Measurement? ph;
  final Measurement? ec;
  final Measurement? solutionTemp;
  final Measurement? tankLevel;
  final DateTime timestamp;

  const ZoneStatus({
    required this.zoneId,
    required this.timestamp,
    this.airTemp,
    this.humidity,
    this.light,
    this.ph,
    this.ec,
    this.solutionTemp,
    this.tankLevel,
  });

  /// Factory Method: construye la zona desde su entrada en Firestore.
  /// Delega en [ZoneStatusAdapter], que es quien conoce los nombres de los
  /// campos.
  factory ZoneStatus.fromFirestore(String zoneId, Map<String, dynamic> entry) =>
      ZoneStatusAdapter.fromFirestore(zoneId, entry);

  Measurement? operator [](HydroVariable variable) => switch (variable) {
        HydroVariable.airTemp => airTemp,
        HydroVariable.humidity => humidity,
        HydroVariable.light => light,
        HydroVariable.ph => ph,
        HydroVariable.ec => ec,
        HydroVariable.solutionTemp => solutionTemp,
        HydroVariable.tankLevel => tankLevel,
      };

  /// El peor nivel entre las variables reportadas. Solo agrega los niveles
  /// que manda el backend; no evalúa rangos.
  EstadoNivel get overallLevel {
    final levels = [
      for (final v in HydroVariable.values)
        if (this[v] case final m?) m.level,
    ];
    if (levels.contains(EstadoNivel.critico)) return EstadoNivel.critico;
    if (levels.contains(EstadoNivel.alerta)) return EstadoNivel.alerta;
    return EstadoNivel.normal;
  }

  String get mensajeEstado => switch (overallLevel) {
        EstadoNivel.normal => 'Condiciones óptimas',
        EstadoNivel.alerta => 'Atención: valores fuera de rango',
        EstadoNivel.critico => 'Acción requerida en la zona',
      };
}
