import 'zone_status.dart';

/// Cultivos con perfil de umbrales en la PWA y en el backend.
///
/// Cualquier cultivo desconocido cae en [jitomate], igual que hace el motor
/// de alertas cuando una lectura no trae cultivo.
enum CropType {
  jitomate('Jitomate'),
  lechuga('Lechuga');

  const CropType(this.label);

  final String label;
}

/// Cuatro cortes de una variable, con el mismo significado que en la PWA:
/// `redMin ≤ yellowMin ≤ yellowMax ≤ redMax`.
///
/// La app **no calcula niveles** con ellos: solo muestra los rangos que ya
/// usa el backend para pintar el semáforo y generar alertas.
class ThresholdRange {
  const ThresholdRange({
    required this.redMin,
    required this.yellowMin,
    required this.yellowMax,
    required this.redMax,
  });

  final double redMin;
  final double yellowMin;
  final double yellowMax;
  final double redMax;

  /// Mezcla un rango guardado sobre el perfil por defecto. Los valores
  /// ausentes o no numéricos se ignoran (misma tolerancia que la PWA).
  ThresholdRange merge(Map<String, dynamic>? guardado) {
    if (guardado == null || guardado.isEmpty) return this;
    return ThresholdRange(
      redMin: _numero(guardado['redMin'], redMin),
      yellowMin: _numero(guardado['yellowMin'], yellowMin),
      yellowMax: _numero(guardado['yellowMax'], yellowMax),
      redMax: _numero(guardado['redMax'], redMax),
    );
  }

  static double _numero(Object? valor, double porDefecto) =>
      valor is num ? valor.toDouble() : porDefecto;
}

/// Umbrales efectivos de un cultivo: perfil por defecto + lo guardado en
/// `greenhouses/{id}`.
class CropThresholds {
  const CropThresholds({
    required this.crop,
    required this.ranges,
    this.personalizadas = const {},
  });

  final CropType crop;
  final Map<HydroVariable, ThresholdRange> ranges;

  /// Variables que tienen valores propios guardados en Firestore (el resto
  /// viene del perfil por defecto).
  final Set<HydroVariable> personalizadas;

  ThresholdRange? de(HydroVariable variable) => ranges[variable];
}

/// Perfiles por defecto de la PWA (`src/lib/cropProfiles.ts`). Se copian a
/// propósito para que la app pueda mostrar los valores efectivos sin depender
/// de la red; hay una prueba que los compara con los del backend.
const Map<CropType, Map<HydroVariable, ThresholdRange>> cropProfiles = {
  CropType.jitomate: {
    HydroVariable.airTemp: ThresholdRange(
      redMin: 12,
      yellowMin: 18,
      yellowMax: 28,
      redMax: 33,
    ),
    HydroVariable.humidity: ThresholdRange(
      redMin: 40,
      yellowMin: 55,
      yellowMax: 80,
      redMax: 90,
    ),
    HydroVariable.light: ThresholdRange(
      redMin: 5000,
      yellowMin: 15000,
      yellowMax: 55000,
      redMax: 75000,
    ),
    HydroVariable.ph: ThresholdRange(
      redMin: 5.0,
      yellowMin: 5.5,
      yellowMax: 6.5,
      redMax: 7.0,
    ),
    HydroVariable.ec: ThresholdRange(
      redMin: 1.5,
      yellowMin: 2.0,
      yellowMax: 3.5,
      redMax: 4.2,
    ),
    HydroVariable.solutionTemp: ThresholdRange(
      redMin: 14,
      yellowMin: 18,
      yellowMax: 24,
      redMax: 27,
    ),
    HydroVariable.tankLevel: ThresholdRange(
      redMin: 20,
      yellowMin: 40,
      yellowMax: 100,
      redMax: 100,
    ),
  },
  CropType.lechuga: {
    HydroVariable.airTemp: ThresholdRange(
      redMin: 10,
      yellowMin: 15,
      yellowMax: 24,
      redMax: 28,
    ),
    HydroVariable.humidity: ThresholdRange(
      redMin: 45,
      yellowMin: 60,
      yellowMax: 80,
      redMax: 90,
    ),
    HydroVariable.light: ThresholdRange(
      redMin: 4000,
      yellowMin: 12000,
      yellowMax: 40000,
      redMax: 60000,
    ),
    HydroVariable.ph: ThresholdRange(
      redMin: 5.0,
      yellowMin: 5.5,
      yellowMax: 6.5,
      redMax: 7.0,
    ),
    HydroVariable.ec: ThresholdRange(
      redMin: 0.5,
      yellowMin: 0.8,
      yellowMax: 1.2,
      redMax: 1.6,
    ),
    HydroVariable.solutionTemp: ThresholdRange(
      redMin: 14,
      yellowMin: 18,
      yellowMax: 24,
      redMax: 26,
    ),
    HydroVariable.tankLevel: ThresholdRange(
      redMin: 20,
      yellowMin: 40,
      yellowMax: 100,
      redMax: 100,
    ),
  },
};

/// Resuelve los umbrales efectivos de un cultivo a partir de lo guardado
/// (`thresholdsByCrop.{cultivo}` o el campo viejo `thresholds` para jitomate).
/// [guardado] ya viene extraído del documento por el adapter: aquí solo se
/// decide cómo se mezcla con el perfil.
CropThresholds resolveCropThresholds(
  CropType crop,
  Map<String, dynamic>? guardado,
) {
  final base = cropProfiles[crop]!;
  final personalizadas = <HydroVariable>{};
  final ranges = <HydroVariable, ThresholdRange>{};

  for (final variable in HydroVariable.values) {
    final propio = guardado?[variable.name];
    final propioMapa = propio is Map ? Map<String, dynamic>.from(propio) : null;
    if (propioMapa != null && propioMapa.isNotEmpty) {
      personalizadas.add(variable);
    }
    ranges[variable] = base[variable]!.merge(propioMapa);
  }

  return CropThresholds(
    crop: crop,
    ranges: ranges,
    personalizadas: personalizadas,
  );
}
