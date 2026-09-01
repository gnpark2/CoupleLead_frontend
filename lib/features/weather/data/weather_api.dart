import 'package:dio/dio.dart';

import 'model/hourly_weather.dart';

class WeatherApi {
  final Dio dio;

  WeatherApi({
    required this.dio,
  });

  Future<List<HourlyWeather>> getPartnerHourlyWeather() async {
    final response = await dio.get(
      '/api/weather/partner/hourly',
    );

    final body = response.data as Map<String, dynamic>;

    final data = body['data'] as Map<String, dynamic>;

    final items = data['items'] as List<dynamic>;

    return items
        .map(
          (item) => HourlyWeather.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
