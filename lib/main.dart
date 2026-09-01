import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'core/desktop/chat_notification_window.dart';
import 'core/desktop/chat_notification_window_initializer.dart';
import 'core/desktop/chat_notification_window_service.dart';
import 'core/desktop/desktop_overlay_window_initializer.dart';
import 'core/desktop/desktop_window_service.dart';
import 'core/notification/local_notification_service.dart';
import 'features/overlay/presentation/overlay_page.dart';

Future<void> main(
  List<String> args,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  /*
   * ==================================
   * Windows Secondary Window 확인
   * ==================================
   */
  if (Platform.isWindows) {
    final windowController = await WindowController.fromCurrentEngine();

    final rawArguments = windowController.arguments;

    if (rawArguments.isNotEmpty) {
      try {
        final data = jsonDecode(
          rawArguments,
        ) as Map<String, dynamic>;

        /*
         * 채팅 알림 전용 Window
         */
        if (data['type'] == 'chat_notification') {
          final mainWindowId = data['mainWindowId']?.toString();

          if (mainWindowId == null || mainWindowId.isEmpty) {
            debugPrint(
              'CHAT NOTIFICATION '
              'mainWindowId 없음',
            );

            return;
          }

          await initializeChatNotificationWindow();

          runApp(
            ChatNotificationWindow(
              controller: windowController,
              mainWindowId: mainWindowId,
            ),
          );

          return;
        }

        if (data['type'] == 'desktop_overlay') {
          await initializeDesktopOverlayWindow();

          tz.initializeTimeZones();

          runApp(
            const ProviderScope(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: OverlayPage(),
              ),
            ),
          );

          return;
        }
      } catch (e) {
        debugPrint(
          'WINDOW ARGUMENT PARSE ERROR: '
          '$e',
        );
      }
    }
  }

  /*
   * ==================================
   * 일반 Couplead Main Window
   * ==================================
   */

  await LocalNotificationService.instance.initialize();

  tz.initializeTimeZones();

  await DesktopWindowService.initializeNormalWindow();

  runApp(
    const ProviderScope(
      child: CoupleadApp(),
    ),
  );

  /*
   * 채팅 Notification Window
   * 미리 hidden 상태로 생성
   */
  if (Platform.isWindows) {
    ChatNotificationWindowService.instance.initialize();
  }
}
