import 'dart:math';
import '../models/sensor_model.dart';

/// Servicio central de datos de sensores.
///
/// Mientras no tengas el backend / IoT conectado, `useMockData = true`
/// devuelve datos de prueba (incluido el JSON exacto que definiste).
/// Cuando tengas tu API real, implementa los métodos marcados con TODO
/// usando el paquete `http` (ya está en pubspec.yaml).
class ApiService {
  static const bool useMockData = true;
  static const String baseUrl = 'https://TU-API.com/api'; // TODO: reemplaza esto

  final Random _rng = Random();

  /// Lectura actual del sensor principal, para el Dashboard.
  Future<SensorReading> getCurrentReading({String sensorId = 'ESP32-01'}) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      return SensorReading(
        sensorId: sensorId,
        ubicacion: 'Zona Tomate A',
        temperatura: 24.5 + _rng.nextDouble() * 2 - 1,
        humedadAire: 65 + _rng.nextDouble() * 4 - 2,
        humedadSuelo: 70 + _rng.nextDouble() * 4 - 2,
        timestamp: DateTime.now(),
      );
    }

    // TODO: reemplaza por tu llamada real, por ejemplo:
    // final res = await http.get(Uri.parse('$baseUrl/sensors/$sensorId/latest'));
    // return SensorReading.fromJson(jsonDecode(res.body));
    throw UnimplementedError('Conecta tu API real en api_service.dart');
  }

  /// Serie histórica simulada de las últimas 24 horas (para mini-gráficas).
  Future<List<ChartPoint>> getHistorico({
    required String metric, // 'temperatura' | 'humedad_aire' | 'humedad_suelo'
    required String rango, // 'hoy' | 'semana' | 'mes'
  }) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final int puntos = switch (rango) {
        'semana' => 7 * 4,
        'mes' => 30,
        _ => 24,
      };
      final Duration paso = switch (rango) {
        'semana' => const Duration(hours: 6),
        'mes' => const Duration(days: 1),
        _ => const Duration(hours: 1),
      };
      final double base = switch (metric) {
        'temperatura' => 24,
        'humedad_aire' => 65,
        _ => 70,
      };

      final now = DateTime.now();
      return List.generate(puntos, (i) {
        final t = now.subtract(paso * (puntos - i));
        final valor = base + sin(i / 3) * 3 + (_rng.nextDouble() * 2 - 1);
        return ChartPoint(t, double.parse(valor.toStringAsFixed(1)));
      });
    }

    // TODO: GET $baseUrl/sensors/history?metric=$metric&range=$rango
    throw UnimplementedError('Conecta tu API real en api_service.dart');
  }

  /// Lista de alertas activas / resueltas.
  Future<List<AlertItem>> getAlertas() async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      final now = DateTime.now();
      return [
        AlertItem(
          id: '1',
          mensaje: 'Temperatura alta detectada (32°C)',
          nivel: EstadoNivel.critico,
          fecha: now.subtract(const Duration(minutes: 12)),
          activa: true,
        ),
        AlertItem(
          id: '2',
          mensaje: 'Humedad del suelo baja (40%)',
          nivel: EstadoNivel.alerta,
          fecha: now.subtract(const Duration(hours: 2)),
          activa: true,
        ),
        AlertItem(
          id: '3',
          mensaje: 'Humedad del aire fuera de rango (85%)',
          nivel: EstadoNivel.alerta,
          fecha: now.subtract(const Duration(hours: 8)),
          activa: false,
        ),
      ];
    }

    // TODO: GET $baseUrl/alerts
    throw UnimplementedError('Conecta tu API real en api_service.dart');
  }
}
