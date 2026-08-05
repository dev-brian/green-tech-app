import 'package:flutter/material.dart';
import 'weather_service.dart'; // Se conecta con el Servicio
import 'weather_model.dart';   // Se conecta con el Modelo

class GreenWeatherScreen extends StatefulWidget {
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
        title: Text('Clima Local - Green Tech'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: FutureBuilder(
          future: futureWeather,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData) {
              final data = snapshot.data!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data.cityName, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text('${data.temperature}°C', style: TextStyle(fontSize: 48, color: Colors.green[700])),
                  Text(data.description.toUpperCase(), style: TextStyle(fontSize: 20)),
                ],
              );
            }
            return Text('No hay datos disponibles.');
          },
        ),
      ),
    );
  }
}