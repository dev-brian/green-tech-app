import 'package:flutter/material.dart';
import 'weather_service.dart'; // Se conecta con el Servicio
// Se conecta con el Modelo

class GreenWeatherScreen extends StatefulWidget {
  const GreenWeatherScreen({super.key});

  @override
  _GreenWeatherScreenState createState() => _GreenWeatherScreenState();
}

class _GreenWeatherScreenState extends State {
  late Future futureWeather;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    futureWeather = _weatherService.fetchWeather('Tlaxcala'); // Puedes cambiar la ciudad aquí
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clima Local - Green Tech'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: FutureBuilder(
          future: futureWeather,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              final data = snapshot.data!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data.cityName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text('${data.temperature}°C', style: TextStyle(fontSize: 48, color: Colors.green[700])),
                  Text(data.description.toUpperCase(), style: const TextStyle(fontSize: 20)),
                ],
              );
            }
            return const Text('No hay datos disponibles.');
          },
        ),
      ),
    );
  }
}