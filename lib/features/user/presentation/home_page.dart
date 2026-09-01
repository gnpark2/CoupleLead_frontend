import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/desktop/desktop_overlay_window_service.dart';
import '../../../core/desktop/desktop_window_service.dart';
import '../../../core/utils/weather_icon_utils.dart';
import '../../anniversary/data/model/anniversary.dart';
import '../../anniversary/presentation/anniversary_page.dart';
import '../../anniversary/presentation/anniversary_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../chat/presentation/chat_visibility_provider.dart';
import '../../media/presentation/media_provider.dart';
import '../../overlay/presentation/overlay_page.dart';
import '../../overlay/presentation/overlay_settings_page.dart';
import '../../weather/presentation/local_time_provider.dart';
import '../../weather/presentation/weather_provider.dart';
import '../../weather/presentation/widgets/hourly_weather_list.dart';
import '../../widget/data/model/couple_widget.dart';
import '../../widget/presentation/widget_provider.dart';
import '../../widget/presentation/widget_realtime_controller.dart';
import '../../widget/presentation/widget_realtime_key.dart';
import '../data/model/user_me.dart';
import '../../chat/presentation/chat_page.dart';
import '../../user/presentation/profile_page.dart';
import '../../anniversary/presentation/anniversary_ui_helper.dart';
import '../../anniversary/presentation/anniversary_date_helper.dart';
import 'user_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final me = ref.watch(meProvider);

    final widget = ref.watch(coupleWidgetProvider);

    final homeAnniversariesAsync = ref.watch(
      homeAnniversaryProvider,
    );

    final currentUser = me.value;

    if (currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    Future<void> _startMediaCall() async {
      try {
        await ref
            .read(
              mediaApiProvider,
            )
            .invite();

        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '상대방의 수락을 기다리는 중입니다.',
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '미디어 공유 요청에 실패했습니다.\n$e',
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Couplead',
        ),
        actions: [
          IconButton(
            tooltip: '내 프로필',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(
                MaterialPageRoute(
                  builder: (_) => const ProfilePage(),
                ),
              );

              ref.invalidate(
                meProvider,
              );

              ref.invalidate(
                coupleWidgetProvider,
              );
            },
            icon: currentUser != null &&
                    currentUser.profileImage != null &&
                    currentUser.profileImage!.isNotEmpty
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(
                      _resolveProfileImage(
                        currentUser.profileImage!,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.account_circle,
                  ),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: () async {
              await ref
                  .read(
                    authControllerProvider.notifier,
                  )
                  .logout();
            },
            icon: const Icon(
              Icons.logout,
            ),
          ),
          IconButton(
            onPressed: () {
              ref.invalidate(
                meProvider,
              );

              ref.invalidate(
                coupleWidgetProvider,
              );
            },
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          IconButton(
            tooltip: '영상 / 화면 공유',
            onPressed: _startMediaCall,
            icon: const Icon(
              Icons.video_call,
            ),
          ),
          /*
     * 오버레이 실행
     */
          IconButton(
            tooltip: '오버레이 실행',
            icon: const Icon(
              Icons.picture_in_picture_alt,
            ),
            // onPressed: () async {
            //   if (!DesktopWindowService.isSupported) {
            //     return;
            //   }

            //   await DesktopWindowService.applyOverlayWindow();

            //   if (!context.mounted) {
            //     return;
            //   }

            //   Navigator.of(
            //     context,
            //   ).push(
            //     MaterialPageRoute(
            //       builder: (_) => const OverlayPage(),
            //     ),
            //   );
            // },
            onPressed: () async {
              await DesktopOverlayWindowService.instance.show();
            },
          ),

          /*
     * 오버레이 설정
     */
          IconButton(
            tooltip: '오버레이 설정',
            icon: const Icon(
              Icons.tune,
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).push(
                MaterialPageRoute(
                  builder: (_) => const OverlaySettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(
            meProvider,
          );

          ref.invalidate(
            coupleWidgetProvider,
          );

          ref.invalidate(
            homeAnniversaryProvider,
          );

          await Future.wait([
            ref.read(
              coupleWidgetProvider.future,
            ),
            ref.read(
              homeAnniversaryProvider.future,
            ),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            me.when(
              data: (user) {
                return Text(
                  '${user.nickname}님',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(
              height: 20,
            ),
            widget.when(
              data: (data) {
                ref.watch(
                  widgetRealtimeProvider(
                    WidgetRealtimeKey(
                      coupleId: data.coupleId,
                      partnerId: data.partnerId,
                    ),
                  ),
                );

                return _CoupleWidgetCard(
                  widget: data,
                  me: currentUser,
                  homeAnniversariesAsync: homeAnniversariesAsync,
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (
                error,
                stackTrace,
              ) {
                return _WidgetError(
                  error: error,
                  onRetry: () {
                    ref.invalidate(
                      coupleWidgetProvider,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CoupleWidgetCard extends StatelessWidget {
  final CoupleWidget widget;

  final UserMe me;

  final AsyncValue<List<Anniversary>> homeAnniversariesAsync;

  const _CoupleWidgetCard({
    required this.widget,
    required this.me,
    required this.homeAnniversariesAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PartnerCard(
          widget: widget,
        ),
        const SizedBox(
          height: 16,
        ),
        _DaysTogetherCard(
          widget: widget,
        ),
        const SizedBox(
          height: 16,
        ),
        homeAnniversariesAsync.when(
          data: (anniversaries) {
            return _HomeAnniversarySection(
              anniversaries: anniversaries,
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (
            error,
            stackTrace,
          ) {
            return const Text(
              '기념일을 불러오지 못했습니다.',
            );
          },
        ),
        const SizedBox(
          height: 16,
        ),
        _WeatherCard(
          widget: widget,
        ),
        const SizedBox(
          height: 16,
        ),
        _ChatCard(
          widget: widget,
        ),
      ],
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final CoupleWidget widget;

  const _PartnerCard({
    required this.widget,
  });

  @override
  Widget build(BuildContext context) {
    final status = widget.partnerOnline ? '온라인' : '오프라인';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                widget.partnerNickname.isNotEmpty
                    ? widget.partnerNickname[0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(
              width: 16,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerNickname,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(status),
                  if (!widget.partnerOnline &&
                      widget.partnerLastSeen != null) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      '마지막 접속: '
                      '${widget.partnerLastSeen}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaysTogetherCard extends StatelessWidget {
  final CoupleWidget widget;

  const _DaysTogetherCard({
    required this.widget,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '함께한 시간',
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              '${widget.daysTogether}일',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherCard extends ConsumerWidget {
  final CoupleWidget widget;

  const _WeatherCard({
    required this.widget,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final partner = widget.partner;

    final hourlyAsync = ref.watch(
      partnerHourlyWeatherProvider,
    );

    final temperature = partner?.temperature;

    final condition = partner?.weatherCondition;

    final timezone = partner?.timezone;

    final localTimeAsync = timezone == null
        ? null
        : ref.watch(
            localTimeProvider(
              timezone,
            ),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
             * 현재 날씨
             */
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 32,
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner?.city ?? '지역 정보 없음',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (localTimeAsync != null)
                        localTimeAsync.when(
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

                            return Text(
                              '현지 시간 '
                              '$hour:$minute',
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (
                            error,
                            stackTrace,
                          ) =>
                              const SizedBox.shrink(),
                        ),
                      if (condition != null)
                        Text(
                          condition,
                        ),
                    ],
                  ),
                ),
                if (condition != null)
                  Icon(
                    WeatherIconUtils.fromCondition(
                      condition,
                    ),
                    size: 34,
                  ),
                if (condition != null)
                  const SizedBox(
                    width: 10,
                  ),
                if (temperature != null)
                  Text(
                    '${temperature.toStringAsFixed(1)}°',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            const Divider(),
            const SizedBox(
              height: 12,
            ),
            Text(
              '시간별 날씨',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(
              height: 12,
            ),

            /*
             * 48시간 예보
             */
            hourlyAsync.when(
              data: (
                items,
              ) {
                if (items.isEmpty) {
                  return const Text(
                    '시간별 날씨 정보가 없습니다.',
                  );
                }

                return HourlyWeatherList(
                  items: items,
                );
              },
              loading: () {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              error: (
                error,
                stackTrace,
              ) {
                return const Text(
                  '시간별 날씨를 불러오지 못했습니다.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCard extends ConsumerWidget {
  final CoupleWidget widget;

  const _ChatCard({
    required this.widget,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.chat_bubble_outline,
        ),
        title: const Text(
          '채팅',
        ),
        subtitle: widget.lastMessageAt != null
            ? Text(
                '마지막 메시지 '
                '${widget.lastMessageAt}',
              )
            : const Text(
                '아직 메시지가 없습니다.',
              ),
        trailing: widget.unreadCount > 0
            ? Badge(
                label: Text(
                  widget.unreadCount.toString(),
                ),
              )
            : const Icon(
                Icons.chevron_right,
              ),
        // onTap: () async {
        //   debugPrint(
        //     '[CHAT DEBUG] '
        //     '_ChatCard 클릭 전 '
        //     'current=${ref.read(currentChatCoupleIdProvider)}',
        //   );

        //   ref
        //       .read(
        //         currentChatCoupleIdProvider.notifier,
        //       )
        //       .state = widget.coupleId;

        //   debugPrint(
        //     '[CHAT DEBUG] '
        //     '_ChatCard에서 설정 후 '
        //     'current=${ref.read(currentChatCoupleIdProvider)}',
        //   );

        //   try {
        //     await Navigator.of(context).push(
        //       MaterialPageRoute(
        //         builder: (_) => ChatPage(
        //           coupleId: widget.coupleId,
        //           partnerId: widget.partnerId,
        //           partnerNickname: widget.partnerNickname,
        //           partnerProfileImage: widget.partnerProfileImage,
        //         ),
        //       ),
        //     );
        //   } finally {
        //     debugPrint(
        //       '[CHAT DEBUG] '
        //       '_ChatCard finally 진입 전 '
        //       'current=${ref.read(currentChatCoupleIdProvider)}',
        //     );

        //     ref
        //         .read(
        //           currentChatCoupleIdProvider.notifier,
        //         )
        //         .state = null;

        //     debugPrint(
        //       '[CHAT DEBUG] '
        //       '_ChatCard finally에서 null 설정 후 '
        //       'current=${ref.read(currentChatCoupleIdProvider)}',
        //     );
        //   }

        //   if (!context.mounted) {
        //     return;
        //   }

        //   final refreshedWidget = await ref.refresh(
        //     coupleWidgetProvider.future,
        //   );

        //   debugPrint(
        //     'CHAT 종료 후 unreadCount='
        //     '${refreshedWidget.unreadCount}',
        //   );
        // },
        onTap: () async {
          await Navigator.of(
            context,
          ).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                coupleId: widget.coupleId,
                partnerId: widget.partnerId,
                partnerNickname: widget.partnerNickname,
                partnerProfileImage: widget.partnerProfileImage,
              ),
            ),
          );

          if (!context.mounted) {
            return;
          }

          final refreshedWidget = await ref.refresh(
            coupleWidgetProvider.future,
          );

          debugPrint(
            'CHAT 종료 후 unreadCount='
            '${refreshedWidget.unreadCount}',
          );
        },
      ),
    );
  }
}

class _WidgetError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _WidgetError({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
            ),
            const SizedBox(
              height: 12,
            ),
            const Text(
              '커플 정보를 불러오지 못했습니다.',
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 16,
            ),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _resolveProfileImage(
  String image,
) {
  if (image.startsWith(
        'http://',
      ) ||
      image.startsWith(
        'https://',
      )) {
    return image;
  }

  return '${ApiConstants.baseUrl}$image';
}

class _HomeAnniversarySection extends StatelessWidget {
  final List<Anniversary> anniversaries;

  const _HomeAnniversarySection({
    required this.anniversaries,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '기념일',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) => const AnniversaryPage(),
                      ),
                    );

                    /*
   * AnniversaryPage에서
   * Home 표시 설정이 바뀌었을 수 있으므로
   * 돌아왔을 때 재조회
   */
                    if (!context.mounted) {
                      return;
                    }

                    // 여기서는 StatelessWidget이라 ref가 없음.
                    // 따라서 다음 단계에서
                    // ConsumerWidget으로 변경하거나
                    // HomePage 쪽 provider 갱신에 맡겨도 됨.
                  },
                  child: const Text(
                    '전체 보기',
                  ),
                ),
              ],
            ),
            if (anniversaries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 20,
                ),
                child: Center(
                  child: Text(
                    'Home에 표시할 기념일이 없습니다.',
                  ),
                ),
              ),
            for (final anniversary in anniversaries)
              _HomeAnniversaryItem(
                anniversary: anniversary,
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeAnniversaryItem extends StatelessWidget {
  final Anniversary anniversary;

  const _HomeAnniversaryItem({
    required this.anniversary,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final dDay = calculateAnniversaryDDay(
      anniversaryDate: anniversary.anniversaryDate,
      repeatType: anniversary.repeatType,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            anniversaryIcon(
              anniversary.type,
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
                  anniversary.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  '${anniversaryTypeLabel(anniversary)}'
                  ' · '
                  '${anniversary.anniversaryDate}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatAnniversaryDDay(
              dDay,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
