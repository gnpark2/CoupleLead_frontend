import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../../features/media_overlay/data/model/media_overlay_settings.dart';

class DesktopMediaOverlayWindowService {
  DesktopMediaOverlayWindowService._();

  static final instance = DesktopMediaOverlayWindowService._();

  WindowController? _controller;

  MediaOverlaySettings _settings = const MediaOverlaySettings();

  bool get isSupported => Platform.isWindows || Platform.isMacOS;

  final ValueNotifier<bool> overlayActive = ValueNotifier<bool>(
    false,
  );

  void handleOverlayClosed() {
    debugPrint(
      '[MEDIA OVERLAY] '
      'before active=${overlayActive.value}',
    );

    overlayActive.value = false;

    debugPrint(
      '[MEDIA OVERLAY] '
      'after active=${overlayActive.value}',
    );
  }

  Future<void> show() async {
    if (!isSupported) {
      return;
    }

    final existing = _controller;

    if (existing != null) {
      try {
        final success = await existing.invokeMethod(
          'start_media_overlay',
          _settings.toJson(),
        );

        await existing.show();

        if (success == true) {
          overlayActive.value = true;
        }

        return;
      } catch (e) {
        debugPrint(
          '[MEDIA OVERLAY] '
          'existing window unavailable: $e',
        );

        _controller = null;
      }
    }

    final mainWindow = await WindowController.fromCurrentEngine();

    final created = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(
          {
            'type': 'media_overlay',
            'mainWindowId': mainWindow.windowId,

            /*
         * 최초 생성되는 Overlay Engine에게도
         * 선택한 레이아웃 전달
         */
            'settings': _settings.toJson(),
          },
        ),
      ),
    );

    _controller = created;

    /*
     * 새 Flutter Engine은
     * 자기 쪽에서 LiveKit에 연결한다.
     */
    await created.show();

    overlayActive.value = true;
  }

  Future<void> applySettings(
    MediaOverlaySettings settings,
  ) async {
    _settings = settings;

    final controller = _controller;

    if (controller == null) {
      return;
    }

    try {
      await controller.invokeMethod(
        'apply_media_overlay_settings',
        settings.toJson(),
      );
    } catch (e) {
      debugPrint(
        '[MEDIA OVERLAY] '
        'apply settings failed: $e',
      );
    }
  }

  Future<void> hide() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    try {
      await controller.hide();
    } catch (e) {
      debugPrint(
        '[MEDIA OVERLAY] '
        'hide failed: $e',
      );

      _controller = null;
    }
  }

  // Future<void> close() async {
  //   final controller = _controller;

  //   if (controller == null) {
  //     return;
  //   }

  //   try {
  //     await controller.invokeMethod(
  //       'close_media_overlay',
  //     );
  //   } catch (e) {
  //     debugPrint(
  //       '[MEDIA OVERLAY] '
  //       'close failed: $e',
  //     );
  //   } finally {
  //     _controller = null;
  //   }
  // }

  Future<void> stop() async {
    final controller = _controller;

    overlayActive.value = false;

    if (controller == null) {
      return;
    }

    try {
      await controller.invokeMethod(
        'stop_media_overlay',
      );
    } catch (e) {
      debugPrint(
        '[MEDIA OVERLAY] '
        'stop failed: $e',
      );
    }
  }
}
