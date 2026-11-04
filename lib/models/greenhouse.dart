import 'zone_status.dart';

/// Rango que el productor configuró para una variable de un cultivo.
///
/// Los umbrales son una referencia local (se guardan en el dispositivo)
/// para tener a la mano lo que necesita cada cosecha. El nivel que pinta
/// el Dashboard (ok/alerta/crítico) lo sigue mandando el backend: la app
/// no calcula niveles.
class VariableThreshold {
  const VariableThreshold({required this.min, required this.max});

  /// Valor mínimo del rango aceptado.
  final double min;

  /// Valor máximo del rango aceptado.
  final double max;

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  factory VariableThreshold.fromJson(Map<String, dynamic> json) =>
      VariableThreshold(
        min: (json['min'] as num).toDouble(),
        max: (json['max'] as num).toDouble(),
      );
}

/// Un cultivo (fruta o cosecha) dentro de un invernadero, con sus umbrales
/// por variable hidropónica.
class Crop {
  const Crop({
    required this.id,
    required this.name,
    this.thresholds = const {},
  });

  final String id;
  final String name;

  /// Umbrales configurados por el productor. Las variables sin entrada
  /// quedan sin umbral.
  final Map<HydroVariable, VariableThreshold> thresholds;

  Crop copyWith({
    String? name,
    Map<HydroVariable, VariableThreshold>? thresholds,
  }) =>
      Crop(
        id: id,
        name: name ?? this.name,
        thresholds: thresholds ?? this.thresholds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'thresholds': {
          for (final entry in thresholds.entries)
            entry.key.name: entry.value.toJson(),
        },
      };

  factory Crop.fromJson(Map<String, dynamic> json) {
    final thresholds = <HydroVariable, VariableThreshold>{};
    final raw = json['thresholds'] as Map<String, dynamic>? ?? const {};
    for (final entry in raw.entries) {
      final variable = HydroVariable.values.asNameMap()[entry.key];
      // Variable desconocida (p. ej. de una versión vieja): se ignora.
      if (variable == null) continue;
      thresholds[variable] =
          VariableThreshold.fromJson(entry.value as Map<String, dynamic>);
    }
    return Crop(
      id: json['id'] as String,
      name: json['name'] as String,
      thresholds: thresholds,
    );
  }
}

/// Un invernadero del productor con sus cultivos.
class Greenhouse {
  const Greenhouse({
    required this.id,
    required this.name,
    this.location = '',
    this.crops = const [],
  });

  final String id;
  final String name;

  /// Ubicación o nota corta (opcional).
  final String location;
  final List<Crop> crops;

  Greenhouse copyWith({
    String? name,
    String? location,
    List<Crop>? crops,
  }) =>
      Greenhouse(
        id: id,
        name: name ?? this.name,
        location: location ?? this.location,
        crops: crops ?? this.crops,
      );

  /// El cultivo con ese id, o null.
  Crop? cropById(String cropId) {
    for (final crop in crops) {
      if (crop.id == cropId) return crop;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'crops': [for (final crop in crops) crop.toJson()],
      };

  factory Greenhouse.fromJson(Map<String, dynamic> json) => Greenhouse(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String? ?? '',
        crops: [
          for (final crop in json['crops'] as List<dynamic>? ?? const [])
            Crop.fromJson(crop as Map<String, dynamic>),
        ],
      );
}

/// Contador para que dos ids generados en el mismo microsegundo no
/// coincidan.
var _contadorId = 0;

/// Id corto y único para invernaderos y cultivos nuevos.
String nuevoId() {
  final tiempo = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$tiempo-${(_contadorId++).toRadixString(36)}';
}
