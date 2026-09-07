import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

import '../../features/overlay/data/model/overlay_settings.dart';

class DesktopOverlayWindowService {
  DesktopOverlayWindowService._();

  static final instance = DesktopOverlayWindowService._();

  WindowController? _controller;

  OverlaySettings? _latestSettings;

  bool get _supported => Platform.isWindows || Platform.isMacOS;

  Future<void> show() async {
    if (!_supported) {
      return;
    }

    final existing = _controller;

    /*
     * 기존 Overlay Window
     */
    if (existing != null) {
      try {
        final latest = _latestSettings;

        if (latest != null) {
          await existing.invokeMethod(
            'apply_settings',
            latest.toJson(),
          );
        }

        await existing.show();

        return;
      } catch (e) {
        debugPrint(
          '[OVERLAY WINDOW] '
          'existing window unavailable: $e',
        );

        _controller = null;
      }
    }

    /*
     * 새 Overlay Window
     */
    final mainWindow = await WindowController.fromCurrentEngine();

    final created = await WindowController.create(
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

    _controller = created;

    /*
     * 첫 실행은 Overlay Provider가
     * storage에서 직접 읽는다.
     */
    await created.show();
  }

  Future<void> applySettings(
    OverlaySettings settings,
  ) async {
    if (!_supported) {
      return;
    }

    /*
     * 가장 최근 값 기억
     */
    _latestSettings = settings;

    final controller = _controller;

    /*
     * Overlay 창이 아직 생성되지 않았으면
     * 저장만 해둔다.
     */
    if (controller == null) {
      return;
    }

    try {
      await controller.invokeMethod(
        'apply_settings',
        settings.toJson(),
      );

      debugPrint(
        '[OVERLAY WINDOW] '
        'settings sent '
        '${settings.toJson()}',
      );
    } catch (e) {
      debugPrint(
        '[OVERLAY WINDOW] '
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
        '[OVERLAY WINDOW] '
        'hide failed: $e',
      );

      _controller = null;
    }
  }
}
