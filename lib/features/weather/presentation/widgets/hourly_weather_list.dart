import 'package:flutter/material.dart';

import '../../../../core/ui/desktop_drag_scroll_behavior.dart';
import '../../../../core/utils/weather_icon_utils.dart';
import '../../data/model/hourly_weather.dart';

class HourlyWeatherList extends StatelessWidget {
  final List<HourlyWeather> items;

  const HourlyWeatherList({
    super.key,
    required this.items,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height: 120,
      child: ScrollConfiguration(
        behavior: const DesktopDragScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (
            context,
            index,
          ) {
            return const SizedBox(
              width: 8,
            );
          },
          itemBuilder: (
            context,
            index,
          ) {
            return _HourlyWeatherTile(
              weather: items[index],
              isFirst: index == 0,
            );
          },
        ),
      ),
    );
  }
}

class _HourlyWeatherTile extends StatelessWidget {
  final HourlyWeather weather;
  final bool isFirst;

  const _HourlyWeatherTile({
    required this.weather,
    required this.isFirst,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hour = weather.time.hour.toString().padLeft(
          2,
          '0',
        );

    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          12,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isFirst ? '현재' : '$hour시',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Icon(
            WeatherIconUtils.fromWeatherCode(
              weather.weatherCode,
            ),
            size: 27,
          ),
          Text(
            '${weather.temperature.round()}°',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
