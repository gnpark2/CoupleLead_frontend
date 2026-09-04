import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/device/presentation/device_provider.dart';
import '../../features/media/presentation/media_provider.dart';
import '../../features/media/presentation/media_room_provider.dart';
import '../../features/anniversary/presentation/anniversary_provider.dart';
import '../../features/couple/presentation/couple_provider.dart';
import '../../features/couple/presentation/couple_realtime_provider.dart';
import '../../features/user/presentation/user_provider.dart';
import '../../features/widget/presentation/widget_provider.dart';
import '../../features/media/domain/media_invite.dart';
import '../../features/media/presentation/media_realtime_provider.dart';
import '../notification/mobile_push_service.dart';

class AuthenticatedSessionListener extends ConsumerStatefulWidget {
  final Widget child;

  const AuthenticatedSessionListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AuthenticatedSessionListener> createState() =>
      _AuthenticatedSessionListenerState();
}

class _AuthenticatedSessionListenerState
    extends ConsumerState<AuthenticatedSessionListener> {
  int? _subscribedUserId;

  bool _navigating = false;

  int? _mediaSubscribedUserId;

  bool _pushNavigationChecked = false;

  int? _pushRegisteredUserId;
  
  @override
  Widget build(
    BuildContext context,
  ) {
    final meAsync = ref.watch(
      meProvider,
    );

    meAsync.whenData(
      (me) {
        /*
     * ==================================
     * 1. Mobile Push
     * ==================================
     */
        if ((Platform.isAndroid || Platform.isIOS) &&
            _pushRegisteredUserId != me.id) {
          _pushRegisteredUserId = me.id;

          WidgetsBinding.instance.addPostFrameCallback(
            (_) async {
              if (!mounted) {
                return;
              }

              final deviceApi = ref.read(
                deviceApiProvider,
              );

              await MobilePushService.instance.registerMobileDevice(
                deviceApi,
              );

              MobilePushService.instance.startTokenRefreshListener(
                deviceApi,
              );
            },
          );
        }

        /*
     * ==================================
     * 2. FCM pending navigation
     * ==================================
     */
        if (!_pushNavigationChecked) {
          _pushNavigationChecked = true;

          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              if (!mounted) {
                return;
              }

              MobilePushService.instance.openPendingNavigation();
            },
          );
        }

        /*
     * ==================================
     * 3. Realtime 중복 방지
     * ==================================
     */
        if (_subscribedUserId == me.id) {
          return;
        }

        _subscribedUserId = me.id;

        /*
     * ==================================
     * 4. Couple realtime
     * ==================================
     */
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (!mounted) {
              return;
            }

            ref
                .read(
                  coupleRealtimeProvider(
                    me.id,
                  ),
                )
                .start(
                  onConnected: _onCoupleConnected,
                  onDisconnected: _onCoupleDisconnected,
                );
          },
        );

        /*
     * ==================================
     * 5. Media realtime
     * ==================================
     */
        if (_mediaSubscribedUserId != me.id) {
          _mediaSubscribedUserId = me.id;

          ref
              .read(
                mediaRealtimeProvider(
                  me.id,
                ),
              )
              .start(
                onInvite: _onMediaInvite,
                onAccepted: _onMediaAccepted,
                onRejected: _onMediaRejected,
                onMediaLeft: _onMediaLeft,
              );
        }
      },
    );

    return widget.child;
  }

  Future<void> _onCoupleConnected() async {
    if (!mounted) {
      return;
    }

    ref.invalidate(
      coupleWidgetProvider,
    );

    ref.invalidate(
      anniversaryListProvider,
    );

    ref.invalidate(
      homeAnniversaryProvider,
    );

    /*
     * 이미 연결 페이지에 있다면
     * Home으로 이동
     */
    final location = GoRouterState.of(context).matchedLocation;

    if (location == '/couple/connect') {
      context.go(
        '/home',
      );
    }
  }

  Future<void> _onCoupleDisconnected() async {
    if (!mounted || _navigating) {
      return;
    }

    _navigating = true;

    /*
     * 이전 커플의 데이터를 모두 제거
     */
    ref.invalidate(
      coupleWidgetProvider,
    );

    ref.invalidate(
      anniversaryListProvider,
    );

    ref.invalidate(
      homeAnniversaryProvider,
    );

    ref.invalidate(
      coupleInviteCodeProvider,
    );

    if (!mounted) {
      return;
    }

    /*
     * 어느 화면에 있든 연결 페이지로 이동
     */
    context.go(
      '/couple/connect',
    );

    _navigating = false;
  }

  Future<void> _onMediaInvite(
    MediaInvite invite,
  ) async {
    if (!mounted) {
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            '미디어 공유 요청',
          ),
          content: Text(
            '${invite.callerNickname}님이 '
            '영상/화면 공유를 시작하려고 합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                '거절',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                '수락',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    final api = ref.read(
      mediaApiProvider,
    );

    if (accepted == true) {
      await api.accept(
        callId: invite.callId,
        callerUserId: invite.callerUserId,
      );

      if (!mounted) {
        return;
      }

      context.push(
        '/media',
      );

      return;
    }

    await api.reject(
      callId: invite.callId,
      callerUserId: invite.callerUserId,
    );
  }

  void _onMediaAccepted(
    String callId,
  ) {
    if (!mounted) {
      return;
    }

    context.push(
      '/media',
    );
  }

  void _onMediaRejected(
    String callId,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '상대방이 미디어 공유 요청을 거절했습니다.',
        ),
      ),
    );
  }

  Future<void> _onMediaLeft(
    Map<String, dynamic> data,
  ) async {
    if (!mounted) {
      return;
    }

    debugPrint(
      '[MEDIA] 상대방 미디어 룸 종료: $data',
    );

    /*
   * 상대방이 방을 나갔으므로
   * 내 LiveKit 연결도 종료
   *
   * 여기서는 mediaApi.leave()를 호출하지 않는다.
   */
    await ref
        .read(
          mediaRoomProvider.notifier,
        )
        .disconnect();

    if (!mounted) {
      return;
    }

    /*
   * 현재 어느 화면에 있더라도 Home으로 이동
   */
    context.go(
      '/home',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '상대방이 미디어 공유를 종료했습니다.',
        ),
      ),
    );
  }
}
