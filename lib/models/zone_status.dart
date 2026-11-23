import '../adapters/zone_status_adapter.dart';
import 'sensor_model.dart';

/// Las 7 variables hidropónicas que reporta cada zona del invernadero.
///
/// Solo identifica la variable. Cómo se muestra (nombre, unidad, ícono,
/// decimales y grupo) sale de la tabla `variableSpecs` en
/// lib/config/variable_config.dart.
enum HydroVariable { airTemp, humidity, light, ph, ec, solutionTemp, tankLevel }

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
