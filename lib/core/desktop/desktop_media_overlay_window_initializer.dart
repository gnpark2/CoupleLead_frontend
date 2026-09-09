import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeDesktopMediaOverlayWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(
      720,
      480,
    ),
    minimumSize: Size(
      360,
      240,
    ),
    center: true,
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
        true,
      );

      await windowManager.setMinimumSize(
        const Size(
          360,
          240,
        ),
      );

      await windowManager.setAlwaysOnTop(
        true,
      );

      await windowManager.setSkipTaskbar(
        true,
      );

      await windowManager.show();

      await windowManager.focus();
    },
  );
}
