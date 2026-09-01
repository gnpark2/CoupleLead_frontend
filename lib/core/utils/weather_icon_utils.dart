import 'package:flutter/material.dart';

class WeatherIconUtils {
  WeatherIconUtils._();

  static IconData fromCondition(
    String condition,
  ) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny_outlined;

      case 'clouds':
        return Icons.cloud_outlined;

      case 'rain':
      case 'drizzle':
        return Icons.water_drop_outlined;

      case 'snow':
        return Icons.ac_unit;

      case 'thunderstorm':
        return Icons.thunderstorm_outlined;

      default:
        return Icons.cloud_outlined;
    }
  }

  static IconData fromWeatherCode(
    int code,
  ) {
    // Clear
    if (code == 0) {
      return Icons.wb_sunny_outlined;
    }

    // Mainly clear / partly cloudy / overcast
    if (code >= 1 && code <= 3) {
      return Icons.cloud_outlined;
    }

    // Fog
    if (code == 45 || code == 48) {
      return Icons.foggy;
    }

    // Drizzle
    if (code >= 51 && code <= 57) {
      return Icons.water_drop_outlined;
    }

    // Rain
    if (code >= 61 && code <= 67) {
      return Icons.water_drop_outlined;
    }

    // Snow
    if (code >= 71 && code <= 77) {
      return Icons.ac_unit;
    }

    // Rain showers
    if (code >= 80 && code <= 82) {
      return Icons.water_drop_outlined;
    }

    // Snow showers
    if (code == 85 || code == 86) {
      return Icons.ac_unit;
    }

    // Thunderstorm
    if (code >= 95 && code <= 99) {
      return Icons.thunderstorm_outlined;
    }

    return Icons.cloud_outlined;
  }
}
