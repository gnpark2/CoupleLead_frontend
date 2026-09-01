class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  factory HourlyWeather.fromJson(
    Map<String, dynamic> json,
  ) {
    return HourlyWeather(
      time: DateTime.parse(
        json['time'] as String,
      ),
      temperature: (json['temperature'] as num).toDouble(),
      weatherCode: json['weatherCode'] as int,
    );
  }
}
