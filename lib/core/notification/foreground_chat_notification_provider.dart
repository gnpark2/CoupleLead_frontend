import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/chat_visibility_provider.dart';
import '../../features/settings/presentation/notification_settings_provider.dart';
import 'local_notification_service.dart';
import 'mobile_push_service.dart';

final foregroundChatNotificationProvider = Provider<void>(
  (
    ref,
  ) {
    /*
     * 이번 단계에서는 Android만 처리.
     *
     * iOS foreground 알림 정책은
     * 나중에 별도로 추가한다.
     */
    if (!Platform.isAndroid) {
      return;
    }

    final subscription = MobilePushService.instance.foregroundMessages.listen(
      (
        message,
      ) async {
        final data = message.data;

        if (data['type'] != 'CHAT_MESSAGE') {
          return;
        }

        final coupleId = int.tryParse(
          data['coupleId']?.toString() ?? '',
        );

        final senderId = int.tryParse(
          data['senderId']?.toString() ?? '',
        );

        if (coupleId == null || senderId == null) {
          return;
        }

        /*
         * =====================================
         * 1. 현재 채팅방 확인
         * =====================================
         */
        final currentChatCoupleId = ref.read(
          currentChatCoupleIdProvider,
        );

        debugPrint(
          '[FOREGROUND NOTIFICATION] '
          'currentChat=$currentChatCoupleId '
          'incoming=$coupleId',
        );

        /*
         * 현재 바로 그 채팅방을 보고 있다면
         * STOMP가 이미 화면에 메시지를 표시하므로
         * OS 알림은 띄우지 않는다.
         */
        if (currentChatCoupleId == coupleId) {
          debugPrint(
            '[FOREGROUND NOTIFICATION] '
            'SKIP - 현재 채팅방',
          );

          return;
        }

        /*
         * =====================================
         * 2. 사용자 알림 설정 확인
         * =====================================
         */
        final settings = await ref.read(
          notificationSettingsProvider.future,
        );

        if (!settings.chatNotificationEnabled) {
          debugPrint(
            '[FOREGROUND NOTIFICATION] '
            'SKIP - 채팅 알림 OFF',
          );

          return;
        }

        /*
         * 기존 backend FCM notification의
         * title / body를 그대로 사용.
         */
        final nickname = message.notification?.title ?? '상대방';

        final body = message.notification?.body ?? '새 메시지가 도착했습니다.';

        /*
         * =====================================
         * 3. 실제 Android local notification
         * =====================================
         */
        await LocalNotificationService.instance.showAndroidChatNotification(
          nickname: nickname,
          message: body,
          coupleId: coupleId,
          senderId: senderId,
          soundEnabled: settings.soundEnabled,
        );

        debugPrint(
          '[FOREGROUND NOTIFICATION] '
          'SHOW coupleId=$coupleId',
        );
      },
    );

    ref.onDispose(
      () {
        subscription.cancel();
      },
    );
  },
);
