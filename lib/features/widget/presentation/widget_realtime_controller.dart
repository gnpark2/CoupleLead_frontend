import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/desktop/chat_notification_window_service.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/notification/in_app_notification_service.dart';
import '../../../core/notification/local_notification_service.dart';
import '../../../core/websocket/stomp_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../chat/presentation/chat_visibility_provider.dart';
import '../../settings/presentation/notification_settings_provider.dart';
import 'widget_provider.dart';
import 'widget_realtime_key.dart';

final widgetRealtimeProvider = Provider.family<void, WidgetRealtimeKey>(
  (
    ref,
    key,
  ) {
    final stompService = ref.watch(stompServiceProvider);

    final List<StompUnsubscribe> subscriptions = [];

    bool disposed = false;

    Future<void> connect() async {
      if (disposed) {
        return;
      }

      try {
        await stompService.connect(
          onError: (error) {
            debugPrint(
              'STOMP ERROR: $error',
            );
          },
        );

        if (disposed || !stompService.isConnected) {
          return;
        }

        final presenceSubscription = stompService.subscribe(
          destination: '/topic/presence/'
              '${key.partnerId}',
          onMessage: (_) {
            ref.invalidate(
              coupleWidgetProvider,
            );
          },
        );

        if (presenceSubscription != null) {
          subscriptions.add(
            presenceSubscription,
          );
        }

        final chatSubscription = stompService.subscribe(
          destination: '/topic/chat/${key.coupleId}',
          onMessage: (data) async {
            debugPrint(
              'HOME CHAT EVENT RECEIVED: '
              'coupleId=${key.coupleId}',
            );

            final senderId = (data['senderId'] as num?)?.toInt();

            final senderNickname = data['senderNickname']?.toString();

            final type = data['type']?.toString();

            final content = data['content']?.toString();

            /*
     * 기존 unread / Home widget
     * 갱신은 그대로 유지.
     */
            final refreshed = await ref.refresh(
              coupleWidgetProvider.future,
            );

            debugPrint(
              'HOME WIDGET REFRESH: '
              'unreadCount='
              '${refreshed.unreadCount}',
            );

            /*
     * 내가 보낸 메시지는
     * 알림 대상 아님.
     */
            if (senderId == null || senderId != key.partnerId) {
              return;
            }

            /*
     * 현재 해당 채팅방을
     * 직접 보고 있다면 생략.
     */
            final currentChatCoupleId = ref.read(
              currentChatCoupleIdProvider,
            );
            debugPrint(
              '[CHAT DEBUG] '
              '알림 판단 '
              'currentChatCoupleId=$currentChatCoupleId '
              'incomingCoupleId=${key.coupleId}',
            );

            if (currentChatCoupleId == key.coupleId) {
              debugPrint(
                '[CHAT NOTIFICATION] '
                '채팅방을 보고 있어서 생략',
              );

              return;
            }

            /*
     * 알림 설정 확인.
     */
            final notificationSettings = await ref.read(
              notificationSettingsProvider.future,
            );

            if (!notificationSettings.chatNotificationEnabled) {
              debugPrint(
                '[CHAT NOTIFICATION] '
                '알림 OFF',
              );

              return;
            }

            /*
     * 모바일 Push는 이후
     * FCM에서 처리.
     */
            if (!Platform.isWindows) {
              return;
            }

            final notificationBody = type == 'IMAGE'
                ? '사진을 보냈습니다.'
                : (content == null || content.isEmpty)
                    ? '새 메시지가 도착했습니다.'
                    : content;

            await ChatNotificationWindowService.instance.show(
              coupleId: key.coupleId,
              partnerId: key.partnerId,
              nickname: senderNickname ?? refreshed.partnerNickname,
              message: notificationBody,
              profileImage: refreshed.partnerProfileImage,
              soundEnabled: notificationSettings.soundEnabled,
            );

            debugPrint(
              '[CHAT NOTIFICATION] '
              '독립 Window 표시',
            );
          },
        );

        if (chatSubscription != null) {
          subscriptions.add(
            chatSubscription,
          );
        }

        final readSubscription = stompService.subscribe(
          destination: '/topic/chat/read/'
              '${key.coupleId}',
          onMessage: (_) {
            ref.invalidate(
              coupleWidgetProvider,
            );
          },
        );

        if (readSubscription != null) {
          subscriptions.add(
            readSubscription,
          );
        }
      } catch (e) {
        print(
          'Widget STOMP connect error: $e',
        );
      }

      final widgetSubscription = stompService.subscribe(
        destination: '/topic/widget/${key.coupleId}',
        onMessage: (data) async {
          debugPrint(
            'WIDGET EVENT RECEIVED: $data',
          );

          final refreshed = await ref.refresh(
            coupleWidgetProvider.future,
          );

          debugPrint(
            'WIDGET REFRESH COMPLETE: '
            'nickname=${refreshed.partnerNickname}, '
            'profileImage=${refreshed.partnerProfileImage}',
          );
        },
      );

      if (widgetSubscription != null) {
        subscriptions.add(
          widgetSubscription,
        );
      }
    }

    connect();

    ref.onDispose(
      () {
        disposed = true;

        for (final unsubscribe in subscriptions) {
          unsubscribe(
            unsubscribeHeaders: {},
          );
        }

        subscriptions.clear();

        /*
         * 여기서 disconnect 하지 않는다.
         *
         * STOMP 연결은 앱 전체에서
         * 하나를 공유한다.
         */
      },
    );
  },
);
