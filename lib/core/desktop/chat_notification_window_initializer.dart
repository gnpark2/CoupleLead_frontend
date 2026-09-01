import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeChatNotificationWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(
      380,
      116,
    ),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(
    options,
    () async {
      await windowManager.setAsFrameless();

      await windowManager.setResizable(
        false,
      );

      await windowManager.setMaximizable(
        false,
      );

      await windowManager.setMinimizable(
        false,
      );

      await windowManager.setAlwaysOnTop(
        true,
      );

      await windowManager.setSkipTaskbar(
        true,
      );

      /*
       * 생성 직후에는 숨겨둔다.
       */
      await windowManager.hide();
    },
  );
}
