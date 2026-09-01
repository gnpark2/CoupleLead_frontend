import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void>
    initializeDesktopOverlayWindow() async {
  await windowManager
      .ensureInitialized();

  const options =
      WindowOptions(
    size: Size(
      360,
      500,
    ),
    minimumSize: Size(
      260,
      220,
    ),
    center: true,
    backgroundColor:
        Colors.transparent,

    /*
     * 독립 앱처럼 taskbar에
     * 따로 나오지 않도록 한다.
     */
    skipTaskbar: true,

    /*
     * 일반 Window보다 항상 위.
     */
    alwaysOnTop: true,

    titleBarStyle:
        TitleBarStyle.hidden,
    windowButtonVisibility:
        false,
  );

  await windowManager
      .waitUntilReadyToShow(
    options,
    () async {
      await windowManager
          .setAsFrameless();

      /*
       * 사용자가 기존처럼
       * 크기 변경 가능.
       */
      await windowManager
          .setResizable(
        true,
      );

      await windowManager
          .setMinimumSize(
        const Size(
          260,
          220,
        ),
      );

      /*
       * 일반 Window보다 항상 위.
       */
      await windowManager
          .setAlwaysOnTop(
        true,
      );

      await windowManager
          .setSkipTaskbar(
        true,
      );

      await windowManager
          .show();

      await windowManager
          .focus();
    },
  );
}