import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializeDesktopOverlayWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(
      360,
      500,
    ),
    minimumSize: Size(
      260,
      220,
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
          260,
          220,
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
