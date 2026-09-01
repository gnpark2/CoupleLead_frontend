import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';

class DesktopOverlayWindowService {
  DesktopOverlayWindowService._();

  static final instance = DesktopOverlayWindowService._();

  WindowController? _controller;

  Future<void> show() async {
    if (!Platform.isWindows) {
      return;
    }

    /*
     * 이미 Window가 있으면 새로 만들지 않고
     * 기존 Window를 다시 표시한다.
     */
    if (_controller != null) {
      try {
        await _controller!.show();

        return;
      } catch (_) {
        /*
         * Window가 실제로 종료된 경우
         * controller를 버리고 다시 생성한다.
         */
        _controller = null;
      }
    }

    final mainWindow = await WindowController.fromCurrentEngine();

    _controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(
          {
            'type': 'desktop_overlay',
            'mainWindowId': mainWindow.windowId,
          },
        ),
      ),
    );
  }

  Future<void> hide() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    try {
      await controller.hide();
    } catch (_) {
      _controller = null;
    }
  }
}
