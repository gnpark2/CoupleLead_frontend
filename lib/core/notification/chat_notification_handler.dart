import 'dart:io';

import 'package:window_manager/window_manager.dart';

import '../../features/chat/data/model/chat_message.dart';
import 'local_notification_service.dart';

class ChatNotificationHandler {
  ChatNotificationHandler._();

  static Future<void> handle({
    required ChatMessage message,
    required int currentUserId,
    required bool isChatPageVisible,
  }) async {
    /*
     * 내가 보낸 메시지는 알림 X
     */
    if (message.senderId == currentUserId) {
      return;
    }

    /*
     * 현재 채팅방을 보고 있으면 알림 X
     */
    if (isChatPageVisible) {
      return;
    }

    /*
     * Windows에서만 처리
     */
    if (!Platform.isWindows) {
      return;
    }

    final minimized = await windowManager.isMinimized();

    final focused = await windowManager.isFocused();

    /*
     * 최소화되었거나
     * 다른 창에 포커스가 있으면 알림
     */
    if (!minimized && focused) {
      return;
    }

    final body =
        message.type == ChatMessageType.image ? '사진을 보냈습니다.' : message.content;

    await LocalNotificationService.instance.showChatNotification(
      nickname: message.senderNickname ?? 'Couplead',
      message: body,
      coupleId: message.senderId,
    );
  }
}
