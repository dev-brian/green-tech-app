class WeatherData {
  final String cityName;
  final double temperature;
  final String description;

  WeatherData({
    required this.cityName,
    required this.temperature,
    required this.description,
  });

  factory WeatherData.fromJson(Map json) {
    return WeatherData(
      cityName: json['name'],
      temperature: json['main']['temp'].toDouble(),
      description: json['weather'][0]['description'],
    );
  }
}