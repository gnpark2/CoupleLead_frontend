import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';

import 'core/desktop/desktop_media_overlay_window_initializer.dart';
import 'core/desktop/desktop_media_overlay_window_service.dart';
import 'core/notification/firebase_background_handler.dart';
import 'core/notification/mobile_push_service.dart';
import 'features/media_overlay/data/model/media_overlay_settings.dart';
import 'features/media_overlay/presentation/media_overlay_room_provider.dart';
import 'features/media_overlay/presentation/media_overlay_window_app.dart';
import 'features/media_overlay/presentation/overlay_settings_provider.dart';
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
import 'features/media_overlay/presentation/media_overlay_room_provider.dart';

WindowController? mainWindowController;

Future<void> main(
  List<String> args,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  Future<void> _runMediaOverlayWindow(
    WindowController currentWindow,
    Map<String, dynamic> arguments,
  ) async {
    final container = ProviderContainer();

    final rawSettings = arguments['settings'];

    if (rawSettings is Map) {
      final settings = MediaOverlaySettings.fromJson(
        Map<String, dynamic>.from(
          rawSettings,
        ),
      );

      container
          .read(
            mediaOverlaySettingsProvider.notifier,
          )
          .apply(
            settings,
          );

      debugPrint(
        '[MEDIA OVERLAY] '
        'initial layout=${settings.layout}',
      );
    }

    final mainWindowId = arguments['mainWindowId']?.toString();

    if (mainWindowId == null || mainWindowId.isEmpty) {
      return;
    }

    await currentWindow.setWindowMethodHandler(
      (
        call,
      ) async {
        switch (call.method) {
          case 'apply_media_overlay_settings':
            final arguments = call.arguments;

            if (arguments is! Map) {
              return false;
            }

            final json = Map<String, dynamic>.from(
              arguments,
            );

            final settings = MediaOverlaySettings.fromJson(
              json,
            );

            container
                .read(
                  mediaOverlaySettingsProvider.notifier,
                )
                .apply(
                  settings,
                );

            return true;

          case 'start_media_overlay':
            final arguments = call.arguments;

            if (arguments is Map) {
              final settings = MediaOverlaySettings.fromJson(
                Map<String, dynamic>.from(
                  arguments,
                ),
              );

              container
                  .read(
                    mediaOverlaySettingsProvider.notifier,
                  )
                  .apply(
                    settings,
                  );
            }

            final success = await container
                .read(
                  mediaOverlayRoomProvider.notifier,
                )
                .resumeSubscriptions();

            return success;

          // case 'close_media_overlay':
          //   debugPrint(
          //     '[MEDIA OVERLAY] '
          //     'close requested',
          //   );

          //   await container
          //       .read(
          //         mediaOverlayRoomProvider.notifier,
          //       )
          //       .disconnect();

          //   await windowManager.close();

          //   return true;

          case 'stop_media_overlay':
            debugPrint(
              '[MEDIA OVERLAY] '
              'stop requested',
            );

            await container
                .read(
                  mediaOverlayRoomProvider.notifier,
                )
                .disconnect();

            await windowManager.hide();

            return true;

          default:
            return null;
        }
      },
    );

    debugPrint(
      '[MEDIA OVERLAY] '
      'method handler registered',
    );

    await initializeDesktopMediaOverlayWindow();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: MediaOverlayWindowApp(
          mainWindowId: mainWindowId,
        ),
      ),
    );
  }

  /*
   * 중요:
   * 각 Flutter Engine 자신의
   * WindowController를 얻는다.
   */
  if (Platform.isWindows || Platform.isMacOS) {
    final currentWindow = await WindowController.fromCurrentEngine();

    final arguments = _parseWindowArguments(
      currentWindow.arguments,
    );

    final windowType = arguments['type'];

    /*
   * 일반 Overlay
   */
    if (windowType == 'desktop_overlay') {
      await _runOverlayWindow(
        currentWindow,
      );

      return;
    }

    /*
   * Media Overlay
   */
    if (windowType == 'media_overlay') {
      await _runMediaOverlayWindow(
        currentWindow,
        arguments,
      );

      return;
    }

    /*
   * Chat Notification
   */
    if (windowType == 'chat_notification') {
      final mainWindowId = arguments['mainWindowId']?.toString();

      if (mainWindowId == null || mainWindowId.isEmpty) {
        return;
      }

      await initializeChatNotificationWindow();

      runApp(
        ChatNotificationWindow(
          controller: currentWindow,
          mainWindowId: mainWindowId,
        ),
      );

      return;
    }

    /*
   * ==================================
   * 여기까지 왔으면 Main Window
   * ==================================
   */
    mainWindowController = currentWindow;
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
 * Chat Notification 초기화
 */
  if (Platform.isWindows || Platform.isMacOS) {
    await ChatNotificationWindowService.instance.initialize();
  }

/*
 * 중요:
 * Main Window Method Handler는
 * 다른 Desktop Service 초기화가 끝난 뒤
 * 마지막에 등록한다.
 */
  if (mainWindowController != null) {
    await _registerMainWindowHandler(
      mainWindowController!,
    );
  }
}

Future<void> _registerMainWindowHandler(
  WindowController currentWindow,
) async {
  await currentWindow.setWindowMethodHandler(
    (
      call,
    ) async {
      debugPrint(
        '[MAIN WINDOW] '
        'method received=${call.method}',
      );

      switch (call.method) {
        case 'media_overlay_closed':
          debugPrint(
            '[MAIN WINDOW] '
            'media_overlay_closed received',
          );

          DesktopMediaOverlayWindowService.instance.handleOverlayClosed();

          return true;

        /*
         * 채팅 알림 Window 등 Main Window가
         * 받아야 하는 method가 있다면
         * 여기에 모두 추가해야 한다.
         */

        default:
          debugPrint(
            '[MAIN WINDOW] '
            'unknown method=${call.method}',
          );

          return null;
      }
    },
  );

  debugPrint(
    '[MAIN WINDOW] '
    'method handler registered',
  );
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
