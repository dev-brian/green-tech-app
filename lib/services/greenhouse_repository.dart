import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/greenhouse.dart';

/// Invernaderos y umbrales guardados en el dispositivo (SharedPreferences).
///
/// Sigue el patrón de SensorDataController: singleton con un ValueNotifier;
/// las pantallas escuchan [greenhouses] y cada mutación reemplaza la lista
/// y la persiste. Es la copia local de trabajo del productor, no la base de
/// datos del backend.
class GreenhouseRepository {
  GreenhouseRepository._();

  static final GreenhouseRepository instance = GreenhouseRepository._();

  static const _prefsKey = 'greenhouses_v1';

  /// Invernaderos actuales, en el orden en que se guardaron.
  final ValueNotifier<List<Greenhouse>> greenhouses = ValueNotifier(const []);

  bool _loaded = false;

  /// Carga lo guardado en el dispositivo. Idempotente: solo lee una vez.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      greenhouses.value = [
        for (final item in decoded)
          Greenhouse.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      // Archivo ilegible: se empieza de cero en vez de romper la app.
      greenhouses.value = const [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final g in greenhouses.value) g.toJson()]),
    );
  }

  /// El invernadero con ese id, o null (solo memoria; llama antes a [load]).
  Greenhouse? greenhouseById(String id) {
    for (final g in greenhouses.value) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> addGreenhouse(Greenhouse greenhouse) async {
    await load();
    greenhouses.value = [...greenhouses.value, greenhouse];
    await _persist();
  }

  Future<void> updateGreenhouse(Greenhouse greenhouse) async {
    await load();
    greenhouses.value = [
      for (final g in greenhouses.value)
        if (g.id == greenhouse.id) greenhouse else g,
    ];
    await _persist();
  }

  Future<void> deleteGreenhouse(String id) async {
    await load();
    greenhouses.value = [
      for (final g in greenhouses.value)
        if (g.id != id) g,
    ];
    await _persist();
  }

  Future<void> addCrop(String greenhouseId, Crop crop) =>
      _mutateCrops(greenhouseId, (crops) => [...crops, crop]);

  Future<void> updateCrop(String greenhouseId, Crop crop) => _mutateCrops(
        greenhouseId,
        (crops) => [for (final c in crops) c.id == crop.id ? crop : c],
      );

  Future<void> deleteCrop(String greenhouseId, String cropId) => _mutateCrops(
        greenhouseId,
        (crops) => [for (final c in crops) if (c.id != cropId) c],
      );

  Future<void> _mutateCrops(
    String greenhouseId,
    List<Crop> Function(List<Crop>) change,
  ) async {
    await load();
    greenhouses.value = [
      for (final g in greenhouses.value)
        if (g.id == greenhouseId) g.copyWith(crops: change(g.crops)) else g,
    ];
    await _persist();
  }

  /// Olvida lo cargado y vacía la lista (solo para pruebas).
  @visibleForTesting
  void reset() {
    _loaded = false;
    greenhouses.value = const [];
  }
}
