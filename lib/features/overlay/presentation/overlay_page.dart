import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/desktop/desktop_window_service.dart';
import '../../../core/utils/weather_icon_utils.dart';
import '../../anniversary/data/model/anniversary.dart';
import '../../anniversary/presentation/anniversary_provider.dart';
import '../../weather/presentation/local_time_provider.dart';
import '../../widget/data/model/couple_widget.dart';
import '../../widget/presentation/widget_provider.dart';
import '../../widget/presentation/widget_refresh_provider.dart';
import '../data/model/overlay_settings.dart';
import 'overlay_anniversary_validator.dart';
import 'overlay_provider.dart';

class OverlayPage extends ConsumerWidget {
  const OverlayPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final settingsAsync = ref.watch(
      overlaySettingsProvider,
    );

    ref.listen(
      anniversaryListProvider,
      (
        previous,
        next,
      ) {
        next.whenData(
          (anniversaries) {
            validateOverlayAnniversary(
              ref: ref,
              anniversaries: anniversaries,
            );
          },
        );
      },
    );

    return settingsAsync.when(
      data: (settings) {
        return _buildOverlay(
          context,
          ref,
          settings,
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (
        error,
        stackTrace,
      ) =>
          Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            '오버레이 설정 오류\n$error',
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    WidgetRef ref,
    OverlaySettings settings,
  ) {
    ref.listen(
      widgetRefreshTickerProvider,
      (
        previous,
        next,
      ) {
        if (next.hasValue) {
          ref.invalidate(
            coupleWidgetProvider,
          );
        }
      },
    );

    final coupleWidgetAsync = ref.watch(
      coupleWidgetProvider,
    );

    final anniversariesAsync = ref.watch(
      anniversaryListProvider,
    );

    return DragToResizeArea(
      resizeEdgeSize: 8,
      resizeEdgeColor: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ClipRRect(
          borderRadius: BorderRadius.circular(
            20,
          ),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: 0.96,
                ),
            child: Column(
              children: [
                _OverlayHeader(
                  //               onClose: () async {
                  //                 /*
                  //  * 1. 현재 오버레이 위치/크기 저장
                  //  */
                  //                 await DesktopWindowService.saveOverlayWindowBounds();

                  //                 /*
                  //  * 2. 일반 Couplead 창으로 복원
                  //  */
                  //                 await DesktopWindowService.restoreNormalWindow();

                  //                 if (!context.mounted) {
                  //                   return;
                  //                 }

                  //                 /*
                  //  * 3. OverlayPage 종료
                  //  */
                  //                 Navigator.of(
                  //                   context,
                  //                 ).pop();
                  //               },
                  onClose: () async {
                    await DesktopWindowService.saveOverlayWindowBounds();

                    await windowManager.hide();
                  },
                ),
                const Divider(
                  height: 1,
                ),
                Expanded(
                  child: coupleWidgetAsync.when(
                    data: (widgetData) {
                      if (widgetData == null) {
                        return const Center(
                          child: Text(
                            '커플 정보를 불러올 수 없습니다.',
                          ),
                        );
                      }

                      return anniversariesAsync.when(
                        data: (
                          anniversaries,
                        ) {
                          Anniversary? selectedAnniversary;

                          if (settings.anniversaryId != null) {
                            for (final anniversary in anniversaries) {
                              if (anniversary.id == settings.anniversaryId) {
                                selectedAnniversary = anniversary;

                                break;
                              }
                            }
                          }

                          return _OverlayContent(
                            settings: settings,
                            widgetData: widgetData,
                            selectedAnniversary: selectedAnniversary,
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (
                          error,
                          stackTrace,
                        ) {
                          return Center(
                            child: Text(
                              '기념일 정보를 불러오지 못했습니다.\n$error',
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (
                      error,
                      stackTrace,
                    ) {
                      return Center(
                        child: Text(
                          '오버레이 정보를 불러오지 못했습니다.\n$error',
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _OverlayHeader({
    required this.onClose,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        windowManager.startDragging();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          8,
          6,
          6,
        ),
        child: Row(
          children: [
            Icon(
              Icons.favorite,
              size: 17,
              color: Theme.of(
                context,
              ).colorScheme.primary,
            ),
            const SizedBox(
              width: 8,
            ),
            const Expanded(
              child: Text(
                'Couplead',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '오버레이 닫기',
              onPressed: onClose,
              icon: const Icon(
                Icons.close,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayContent extends ConsumerWidget {
  final OverlaySettings settings;

  final CoupleWidget widgetData;

  final Anniversary? selectedAnniversary;

  const _OverlayContent({
    required this.settings,
    required this.widgetData,
    required this.selectedAnniversary,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final me = widgetData.me;
    final partner = widgetData.partner;

    return Padding(
      padding: const EdgeInsets.all(
        16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
             * 기념일
             */
            if (settings.showAnniversary && selectedAnniversary != null)
              _AnniversarySection(
                title: selectedAnniversary!.title,
                dDay: _calculateDDay(
                  selectedAnniversary!.anniversaryDate,
                ),
              ),
            if (settings.showAnniversary && selectedAnniversary != null)
              const SizedBox(
                height: 16,
              ),

            /*
             * 나 - 지역 시간
             */
            if (settings.showMyTime && me != null)
              _LiveTimeSection(
                title: '${me.nickname} (나)',
                city: me.city ?? '지역 미설정',
                timezone: me.timezone,
              ),

            /*
             * 나 - 날씨
             */
            if (settings.showMyWeather && me != null)
              Padding(
                padding: EdgeInsets.only(
                  top: settings.showMyTime ? 8 : 0,
                ),
                child: _WeatherSection(
                  city: me.city ?? '지역 미설정',
                  temperature: me.temperature,
                  condition: me.weatherCondition ?? '-',
                ),
              ),

            /*
             * 나 / 상대방 사이 구분선
             */
            if (_showPersonDivider(
              settings: settings,
              meExists: me != null,
              partnerExists: partner != null,
            ))
              const Divider(
                height: 28,
              ),

            /*
             * 상대방 - 지역 시간
             */
            if (settings.showPartnerTime && partner != null)
              _LiveTimeSection(
                title: partner.nickname,
                city: partner.city ?? '지역 미설정',
                timezone: partner.timezone,
              ),

            /*
             * 상대방 - 날씨
             */
            if (settings.showPartnerWeather && partner != null)
              Padding(
                padding: EdgeInsets.only(
                  top: settings.showPartnerTime ? 8 : 0,
                ),
                child: _WeatherSection(
                  city: partner.city ?? '지역 미설정',
                  temperature: partner.temperature,
                  condition: partner.weatherCondition ?? '-',
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _showPersonDivider({
    required OverlaySettings settings,
    required bool meExists,
    required bool partnerExists,
  }) {
    final showMe = meExists && (settings.showMyTime || settings.showMyWeather);

    final showPartner = partnerExists &&
        (settings.showPartnerTime || settings.showPartnerWeather);

    return showMe && showPartner;
  }

  String _formatTime(
    DateTime time,
  ) {
    final hour = time.hour.toString().padLeft(
          2,
          '0',
        );

    final minute = time.minute.toString().padLeft(
          2,
          '0',
        );

    return '$hour:$minute';
  }
}

class _AnniversarySection extends StatelessWidget {
  final String title;

  final int? dDay;

  const _AnniversarySection({
    required this.title,
    required this.dDay,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite,
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge,
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                dDay == null
                    ? '-'
                    : _formatDDay(
                        dDay!,
                      ),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDDay(
    int value,
  ) {
    if (value == 0) {
      return 'D-Day';
    }

    if (value > 0) {
      return 'D-$value';
    }

    return 'D+${value.abs()}';
  }
}

class _TimeSection extends StatelessWidget {
  final String title;
  final String city;
  final String localTime;

  const _TimeSection({
    required this.title,
    required this.city,
    required this.localTime,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        const Icon(
          Icons.access_time,
          size: 22,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium,
              ),
              Text(
                city,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          localTime,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _LiveTimeSection extends ConsumerWidget {
  final String title;
  final String city;
  final String? timezone;

  const _LiveTimeSection({
    required this.title,
    required this.city,
    required this.timezone,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final timezoneValue = timezone;

    if (timezoneValue == null || timezoneValue.isEmpty) {
      return _TimeSection(
        title: title,
        city: city,
        localTime: '--:--',
      );
    }

    final timeAsync = ref.watch(
      localTimeProvider(
        timezoneValue,
      ),
    );

    return timeAsync.when(
      data: (
        time,
      ) {
        final hour = time.hour.toString().padLeft(
              2,
              '0',
            );

        final minute = time.minute.toString().padLeft(
              2,
              '0',
            );

        return _TimeSection(
          title: title,
          city: city,
          localTime: '$hour:$minute',
        );
      },
      loading: () {
        return _TimeSection(
          title: title,
          city: city,
          localTime: '--:--',
        );
      },
      error: (
        error,
        stackTrace,
      ) {
        return _TimeSection(
          title: title,
          city: city,
          localTime: '--:--',
        );
      },
    );
  }
}

class _WeatherSection extends StatelessWidget {
  final String city;
  final double? temperature;
  final String condition;

  const _WeatherSection({
    required this.city,
    required this.temperature,
    required this.condition,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          WeatherIconUtils.fromCondition(
            condition,
          ),
          size: 24,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(
            condition,
          ),
        ),
        if (temperature != null)
          Text(
            '${temperature!.round()}°C',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
      ],
    );
  }
}

int _calculateDDay(
  String anniversaryDate,
) {
  final target = DateTime.parse(
    anniversaryDate,
  );

  final now = DateTime.now();

  final today = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final targetDate = DateTime(
    target.year,
    target.month,
    target.day,
  );

  return targetDate
      .difference(
        today,
      )
      .inDays;
}
