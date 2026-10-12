import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/sensor_model.dart';

class LocationOption {
  final String query;
  final String displayName;

  const LocationOption({required this.query, required this.displayName});
}

class ApiService {
  static String get _apiKey => dotenv.env['WEATHER_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static String _selectedLocation = 'Tlaxcala';

  String get currentLocation => _selectedLocation;

  void setLocation(String location) {
    final value = location.trim();
    _selectedLocation = value.isEmpty ? 'Tlaxcala' : value;
  }

  Future<SensorReading> getCurrentReading(
      {String sensorId = 'ESP32-01'}) async {
    final weather = await _fetchCurrentWeather();
    return SensorReading(
      sensorId: sensorId,
      ubicacion: _selectedLocation,
      temperatura: weather['temp'] as double,
      humedadAire: weather['humidity'] as double,
      humedadSuelo: _soilHumidityFromWeather(weather),
      timestamp: DateTime.now(),
    );
  }

  Future<List<ChartPoint>> getHistorico({
    required String metric,
    required String rango,
  }) async {
    final forecast = await _fetchForecast();
    final points = forecast.map((item) {
      final time = DateTime.parse(item['dt_txt'] as String);
      final value = metric == 'temperatura'
          ? (item['main']['temp'] as num).toDouble()
          : (item['main']['humidity'] as num).toDouble();
      return ChartPoint(time, double.parse(value.toStringAsFixed(1)));
    }).toList();

    final int limit = switch (rango) {
      'semana' => 24,
      'mes' => 40,
      _ => 8,
    };

    return points.take(limit).toList();
  }

  Future<List<AlertItem>> getAlertas() async {
    final weather = await _fetchCurrentWeather();
    final now = DateTime.now();
    final alerts = <AlertItem>[];

    if ((weather['temp'] as double) > 30) {
      alerts.add(AlertItem(
        id: 'temp-alta',
        mensaje:
            'Temperatura alta detectada (${weather['temp'].toStringAsFixed(1)}°C)',
        nivel: EstadoNivel.alerta,
        fecha: now,
        activa: true,
      ));
    }

    if ((weather['humidity'] as double) > 80) {
      alerts.add(AlertItem(
        id: 'humedad-alta',
        mensaje: 'Humedad ambiental elevada (${weather['humidity'].toInt()}%)',
        nivel: EstadoNivel.alerta,
        fecha: now.subtract(const Duration(minutes: 20)),
        activa: true,
      ));
    }

    if ((weather['description'] as String).toLowerCase().contains('rain')) {
      alerts.add(AlertItem(
        id: 'lluvia',
        mensaje: 'Se detectó lluvia en la ubicación actual',
        nivel: EstadoNivel.alerta,
        fecha: now.subtract(const Duration(hours: 1)),
        activa: true,
      ));
    }

    if (alerts.isEmpty) {
      alerts.add(AlertItem(
        id: 'normal',
        mensaje: 'Condiciones estables según el clima actual',
        nivel: EstadoNivel.normal,
        fecha: now,
        activa: false,
      ));
    }

    return alerts;
  }

  Future<List<LocationOption>> searchLocations(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final uri = Uri.parse(
      'https://api.openweathermap.org/geo/1.0/direct?q=$cleanQuery&limit=5&appid=$_apiKey',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('No se pudieron buscar localidades');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((item) {
      final map = item as Map<String, dynamic>;
      final name = map['name'] as String;
      final state = map['state'] ?? '';
      final country = map['country'] as String;
      final suffix =
          [state, country].where((v) => v.toString().isNotEmpty).join(', ');
      return LocationOption(
        query: '$name${suffix.isEmpty ? '' : ', $suffix'}',
        displayName: '$name${suffix.isEmpty ? '' : ' · $suffix'}',
      );
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchCurrentWeather() async {
    final uri = Uri.parse(
      '$_baseUrl/weather?q=$_selectedLocation&appid=$_apiKey&units=metric&lang=es',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar el clima para $_selectedLocation');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final main = body['main'] as Map<String, dynamic>;
    final weather = (body['weather'] as List).first as Map<String, dynamic>;
    return {
      'temp': (main['temp'] as num).toDouble(),
      'humidity': (main['humidity'] as num).toDouble(),
      'description': weather['description'] as String,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchForecast() async {
    final uri = Uri.parse(
      '$_baseUrl/forecast?q=$_selectedLocation&appid=$_apiKey&units=metric&lang=es',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'No se pudo cargar el pronóstico para $_selectedLocation');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['list'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  double _soilHumidityFromWeather(Map<String, dynamic> weather) {
    final humidity = weather['humidity'] as double;
    final description = (weather['description'] as String).toLowerCase();
    if (description.contains('rain')) {
      return (humidity - 8).clamp(20, 95).toDouble();
    }
    if (description.contains('clear')) {
      return (humidity - 2).clamp(20, 95).toDouble();
    }
    return humidity.clamp(20, 95).toDouble();
  }
}
