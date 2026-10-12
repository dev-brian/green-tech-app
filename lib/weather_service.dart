import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'weather_model.dart'; // Se conecta con el archivo del Paso 2

class WeatherService {
  final String apiKey = dotenv.env['WEATHER_API_KEY'] ?? '';

  Future fetchWeather(String city) async {
    final String url = 'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric&lang=es';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return WeatherData.fromJson(json.decode(response.body));
    } else {
      throw Exception('Fallo al cargar el clima. Código: ${response.statusCode}');
    }
  }
}