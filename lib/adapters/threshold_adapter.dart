import '../models/crop_thresholds.dart';

/// Único lugar que conoce los nombres de campo de los umbrales en Firestore.
///
/// `thresholdsByCrop.{jitomate|lechuga}` manda; el campo viejo `thresholds`
/// solo se respeta para jitomate (era el cultivo por defecto). Si no hay
/// nada guardado, se muestran los perfiles por defecto, que son los mismos
/// que usa el backend. La app solo LEE: nunca escribe umbrales.
class ThresholdAdapter {
  static Map<CropType, CropThresholds> fromFirestore(
    Map<String, dynamic>? data,
  ) {
    final byCrop = _mapa(data?['thresholdsByCrop']);
    final legacy = _mapa(data?['thresholds']);

    return {
      for (final crop in CropType.values)
        crop: resolveCropThresholds(
          crop,
          _mapa(byCrop?[crop.name]) ??
              (crop == CropType.jitomate ? legacy : null),
        ),
    };
  }

  static Map<String, dynamic>? _mapa(Object? valor) =>
      valor is Map ? Map<String, dynamic>.from(valor) : null;
}
