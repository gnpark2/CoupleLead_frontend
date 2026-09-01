import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/chat/presentation/chat_page.dart';
import '../navigation/app_navigator.dart';

class ChatNotificationWindowService {
  ChatNotificationWindowService._();

  static final instance = ChatNotificationWindowService._();

  WindowController? _controller;

  WindowController? _mainController;

  Future<void> initialize() async {
    if (!Platform.isWindows) {
      return;
    }

    if (_controller != null) {
      return;
    }

    /*
     * 현재 실행 중인 메인 Couplead Window
     */
    final mainWindow = await WindowController.fromCurrentEngine();

    _mainController = mainWindow;

    /*
     * 알림 Window에서
     * 메인 Window로 보내는 이벤트 수신
     */
    await mainWindow.setWindowMethodHandler(
      (call) async {
        if (call.method == 'openChatFromNotification') {
          final arguments = Map<String, dynamic>.from(
            call.arguments as Map,
          );

          await _handleOpenChat(
            arguments,
          );

          return true;
        }

        return null;
      },
    );

    /*
     * 독립 Notification Window 생성
     */
    _controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(
          {
            'type': 'chat_notification',

            /*
             * Notification Window가
             * 메인 Window를 찾을 수 있도록 전달
             */
            'mainWindowId': mainWindow.windowId,
          },
        ),
      ),
    );

    debugPrintWindow(
      'Notification window created: '
      '${_controller!.windowId}',
    );
  }

  Future<void> show({
    required int coupleId,
    required int partnerId,
    required String nickname,
    required String message,
    String? profileImage,
    required bool soundEnabled,
  }) async {
    if (!Platform.isWindows) {
      return;
    }

    await initialize();

    final controller = _controller;

    if (controller == null) {
      return;
    }

    final data = {
      'coupleId': coupleId,
      'partnerId': partnerId,
      'nickname': nickname,
      'message': message,
      'profileImage': profileImage,
      'soundEnabled': soundEnabled,
    };

    /*
     * Notification Window가 아직
     * handler 등록을 완료하지 않았을 수도 있어서 재시도
     */
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        await controller.invokeMethod(
          'showChatNotification',
          data,
        );

        return;
      } catch (_) {
        await Future<void>.delayed(
          const Duration(
            milliseconds: 100,
          ),
        );
      }
    }

    debugPrintWindow(
      'Notification window '
      'message delivery failed',
    );
  }

  Future<void> _handleOpenChat(
    Map<String, dynamic> data,
  ) async {
    final coupleId = (data['coupleId'] as num?)?.toInt();

    final partnerId = (data['partnerId'] as num?)?.toInt();

    final partnerNickname = data['partnerNickname']?.toString() ?? '';

    final partnerProfileImage = data['partnerProfileImage']?.toString();

    if (coupleId == null || partnerId == null) {
      debugPrintWindow(
        'OPEN CHAT FAILED: '
        'coupleId 또는 partnerId 없음',
      );

      return;
    }

    debugPrintWindow(
      'OPEN CHAT REQUEST '
      'coupleId=$coupleId '
      'partnerId=$partnerId '
      'nickname=$partnerNickname',
    );

    /*
   * 1. 메인 Couplead Window가
   * 최소화되어 있으면 복원
   */
    final minimized = await windowManager.isMinimized();

    if (minimized) {
      await windowManager.restore();
    }

    /*
   * 2. 메인 Window 표시
   */
    await windowManager.show();

    /*
   * 3. 다른 프로그램보다 앞으로
   */
    await windowManager.focus();

    /*
   * Window 복원 직후 Navigator가
   * 안정화될 시간을 조금 준다.
   */
    await Future<void>.delayed(
      const Duration(
        milliseconds: 100,
      ),
    );

    /*
   * 4. Main Navigator 가져오기
   */
    final context = rootNavigatorKey.currentContext;

    if (context == null || !context.mounted) {
      debugPrintWindow(
        'OPEN CHAT FAILED: '
        'rootNavigator context 없음',
      );

      return;
    }

    /*
   * 5. 해당 ChatPage로 이동
   */
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(
      MaterialPageRoute(
        builder: (_) {
          return ChatPage(
            coupleId: coupleId,
            partnerId: partnerId,
            partnerNickname: partnerNickname,
            partnerProfileImage: partnerProfileImage,
          );
        },
      ),
    );

    debugPrintWindow(
      'OPEN CHAT SUCCESS: '
      'coupleId=$coupleId',
    );
  }
}

void debugPrintWindow(
  String message,
) {
  // ignore: avoid_print
  print(
    '[CHAT NOTIFICATION WINDOW] '
    '$message',
  );
}
