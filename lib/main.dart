import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';

import 'core/notification/firebase_background_handler.dart';
import 'core/notification/mobile_push_service.dart';
import 'features/overlay/data/model/overlay_settings.dart';
import 'features/overlay/presentation/overlay_provider.dart';
import 'features/overlay/presentation/overlay_window_app.dart';
import 'firebase_options.dart';
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

  tz.initializeTimeZones();

  /*
   * 중요:
   * 각 Flutter Engine 자신의
   * WindowController를 얻는다.
   */
  final currentWindow = await WindowController.fromCurrentEngine();

  final arguments = _parseWindowArguments(
    currentWindow.arguments,
  );

  final windowType = arguments['type'];

  if (windowType == 'desktop_overlay') {
    await _runOverlayWindow(
      currentWindow,
    );

    return;
  }

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

          // runApp(
          //   const ProviderScope(
          //     child: MaterialApp(
          //       debugShowCheckedModeBanner: false,
          //       home: OverlayPage(),
          //     ),
          //   ),
          // );

          runApp(
            const ProviderScope(
              child: OverlayWindowApp(),
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
   * 모바일 Firebase
   */
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    /*
   * Background FCM handler
   */
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await MobilePushService.instance.initialize();
  }

  /*
   * ==================================
   * 일반 Couplead Main Window
   * ==================================
   */

  await LocalNotificationService.instance.initialize(
    onNotificationTap: (
      payload,
    ) {
      MobilePushService.instance.handleLocalNotificationTap(
        payload,
      );
    },
  );

  final localNotificationLaunchPayload =
      await LocalNotificationService.instance.getLaunchPayload();

  if (localNotificationLaunchPayload != null) {
    MobilePushService.instance.handleLocalNotificationTap(
      localNotificationLaunchPayload,
    );
  }

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

Map<String, dynamic> _parseWindowArguments(
  String raw,
) {
  if (raw.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(
      raw,
    );

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // main window
  }

  return const {};
}

Future<void> _runOverlayWindow(
  WindowController currentWindow,
) async {
  /*
   * =====================================
   * 오버레이 Engine 전용 ProviderContainer
   * =====================================
   *
   * Main Window와 공유하지 않는다.
   */
  final container = ProviderContainer();

  /*
   * =====================================
   * UI를 띄우기 전에 Handler부터 등록
   * =====================================
   *
   * 이게 핵심이다.
   */
  await currentWindow.setWindowMethodHandler(
    (
      call,
    ) async {
      switch (call.method) {
        case 'apply_settings':
          debugPrint(
            '[OVERLAY WINDOW] '
            'apply_settings received',
          );

          final arguments = call.arguments;

          if (arguments is! Map) {
            debugPrint(
              '[OVERLAY WINDOW] '
              'invalid settings arguments',
            );

            return false;
          }

          final json = Map<String, dynamic>.from(
            arguments,
          );

          final settings = OverlaySettings.fromJson(
            json,
          );

          debugPrint(
            '[OVERLAY WINDOW] '
            'received settings '
            '${settings.toJson()}',
          );

          container
              .read(
                overlaySettingsProvider.notifier,
              )
              .applyExternalSettings(
                settings,
              );

          return true;

        default:
          return null;
      }
    },
  );

  debugPrint(
    '[OVERLAY WINDOW] '
    'method handler registered',
  );

  /*
   * Window 설정
   */
  await initializeDesktopOverlayWindow();

  /*
   * 중요:
   *
   * 위 handler에서 사용하는 container와
   * OverlayPage가 사용하는 container가
   * 정확히 같은 객체여야 한다.
   */
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OverlayWindowApp(),
    ),
  );
}
