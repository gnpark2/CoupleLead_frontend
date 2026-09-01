import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/model/hourly_weather.dart';
import '../data/weather_api.dart';

final weatherApiProvider = Provider<WeatherApi>(
  (ref) {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    return WeatherApi(
      dio: dio,
    );
  },
);

final partnerHourlyWeatherProvider =
    AsyncNotifierProvider<PartnerHourlyWeatherController, List<HourlyWeather>>(
  PartnerHourlyWeatherController.new,
);

class PartnerHourlyWeatherController
    extends AsyncNotifier<List<HourlyWeather>> {
  Timer? _timer;

  @override
  Future<List<HourlyWeather>> build() async {
    ref.onDispose(() {
      _timer?.cancel();
    });

    /*
     * 날씨는 10분마다 갱신
     */
    _timer ??= Timer.periodic(
      const Duration(
        minutes: 10,
      ),
      (_) {
        refresh();
      },
    );

    return _load();
  }

  Future<List<HourlyWeather>> _load() {
    return ref
        .read(
          weatherApiProvider,
        )
        .getPartnerHourlyWeather();
  }

  Future<void> refresh() async {
    try {
      final data = await _load();

      state = AsyncData(
        data,
      );
    } catch (error) {
      debugPrint(
        'HOURLY WEATHER REFRESH ERROR: '
        '$error',
      );

      /*
       * 자동 갱신 실패 시 기존 데이터 유지
       */
    }
  }
}
