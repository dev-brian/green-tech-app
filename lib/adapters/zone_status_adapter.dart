import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sensor_model.dart';
import '../models/zone_status.dart';

/// Adapter entre el documento `greenhouses/{id}/state/latest` y el modelo
/// [ZoneStatus].
///
/// Es el ÚNICO lugar de la app que conoce los nombres de los campos de
/// Firestore. Si el backend cambia el contrato, solo se toca este archivo.
/// Ver docs/firestore-contract.md.
class ZoneStatusAdapter {
  ZoneStatusAdapter._();

  static const String _value = 'value';
  static const String _level = 'level';
  static const String _timestamp = 'timestamp';

  static const Map<HydroVariable, String> _fields = {
    HydroVariable.airTemp: 'airTemp',
    HydroVariable.humidity: 'humidity',
    HydroVariable.light: 'light',
    HydroVariable.ph: 'ph',
    HydroVariable.ec: 'ec',
    HydroVariable.solutionTemp: 'solutionTemp',
    HydroVariable.tankLevel: 'tankLevel',
  };

  static const Map<String, EstadoNivel> _levels = {
    'ok': EstadoNivel.normal,
    'warn': EstadoNivel.alerta,
    'critical': EstadoNivel.critico,
  };

  /// Convierte el documento completo: una [ZoneStatus] por cada entrada
  /// (zoneId) que sea un mapa. Las entradas que no lo son se ignoran.
  static Map<String, ZoneStatus> zonesFromDocument(Map<String, dynamic> doc) {
    return {
      for (final entry in doc.entries)
        if (entry.value case final Map<String, dynamic> data)
          entry.key: fromFirestore(entry.key, data),
    };
  }

  /// Convierte la entrada de una zona.
  ///
  /// Es tolerante: una variable ausente o mal formada queda en null, y
  /// `timestamp` puede venir como [Timestamp] de Firestore o como texto
  /// ISO 8601 (así se guarda en la caché local).
  static ZoneStatus fromFirestore(String zoneId, Map<String, dynamic> entry) {
    Measurement? m(HydroVariable v) => measurementFromFirestore(entry[_fields[v]]);
    return ZoneStatus(
      zoneId: zoneId,
      timestamp: _parseTimestamp(entry[_timestamp]),
      airTemp: m(HydroVariable.airTemp),
      humidity: m(HydroVariable.humidity),
      light: m(HydroVariable.light),
      ph: m(HydroVariable.ph),
      ec: m(HydroVariable.ec),
      solutionTemp: m(HydroVariable.solutionTemp),
      tankLevel: m(HydroVariable.tankLevel),
    );
  }

  /// `{value, level}` → [Measurement]. Devuelve null si falta el valor o el
  /// nivel no es uno de `ok`, `warn` o `critical`: la app nunca inventa un
  /// nivel que el backend no mandó.
  static Measurement? measurementFromFirestore(Object? raw) {
    if (raw is! Map) return null;
    final value = raw[_value];
    final level = _levels[raw[_level]];
    if (value is! num || level == null) return null;
    return Measurement(value: value.toDouble(), level: level);
  }

  /// Inverso de [fromFirestore], con la fecha en ISO 8601 para poder
  /// guardarla como JSON en la caché local.
  static Map<String, dynamic> toFirestore(ZoneStatus zone) {
    final levelNames = {for (final e in _levels.entries) e.value: e.key};
    return {
      for (final v in HydroVariable.values)
        if (zone[v] case final m?)
          _fields[v]!: {_value: m.value, _level: levelNames[m.level]},
      _timestamp: zone.timestamp.toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(Object? raw) => switch (raw) {
        Timestamp t => t.toDate(),
        String s => DateTime.tryParse(s) ?? DateTime.now(),
        _ => DateTime.now(),
      };
}
