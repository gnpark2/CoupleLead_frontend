import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'overlay_window_storage.dart';

class DesktopWindowService {
  const DesktopWindowService._();

  static bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static Future<void> initializeNormalWindow() async {
    if (!isSupported) {
      return;
    }

    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: Size(
        1200,
        800,
      ),
      minimumSize: Size(
        900,
        600,
      ),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(
      options,
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  static Future<void> applyOverlayWindow() async {
    if (!isSupported) {
      return;
    }

    await windowManager.setAlwaysOnTop(
      true,
    );

    await windowManager.setResizable(
      true,
    );

    await windowManager.setMinimumSize(
      const Size(
        320,
        230,
      ),
    );

    await windowManager.setAsFrameless();

    await windowManager.setBackgroundColor(
      Colors.transparent,
    );

    await windowManager.setHasShadow(
      false,
    );

    /*
   * 이전 오버레이 위치/크기 조회
   */
    final savedBounds = await OverlayWindowStorage.loadBounds();

    if (savedBounds != null) {
      final safeBounds = await _getSafeOverlayBounds(
        savedBounds,
      );

      await windowManager.setBounds(
        safeBounds,
      );
    } else {
      await windowManager.setSize(
        const Size(
          320,
          230,
        ),
      );

      await windowManager.center();
    }
  }

  static Future<void> restoreNormalWindow() async {
    if (!isSupported) {
      return;
    }

    await windowManager.setAlwaysOnTop(
      false,
    );

    await windowManager.setResizable(
      true,
    );

    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal,
    );

    await windowManager.setSize(
      const Size(
        1200,
        800,
      ),
    );

    await windowManager.center();
  }

  static Future<void> saveOverlayWindowBounds() async {
    if (!isSupported) {
      return;
    }

    final bounds = await windowManager.getBounds();

    await OverlayWindowStorage.saveBounds(
      bounds,
    );
  }

  static Future<Rect> _getSafeOverlayBounds(
    Rect savedBounds,
  ) async {
    final displays = await screenRetriever.getAllDisplays();

    if (displays.isEmpty) {
      return savedBounds;
    }

    /*
   * 저장된 창이 현재 모니터 중 하나와
   * 충분히 겹치는지 확인
   */
    for (final display in displays) {
      final position = display.visiblePosition ?? Offset.zero;

      final size = display.visibleSize ?? display.size;

      final displayRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

      final intersection = savedBounds.intersect(
        displayRect,
      );

      /*
     * 창의 일부라도 적당히 보이면
     * 기존 위치 유지
     */
      if (intersection.width >= 80 && intersection.height >= 80) {
        return savedBounds;
      }
    }

    /*
   * 모든 화면 밖이라면
   * 메인 모니터 기준으로 복구
   */
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();

    final position = primaryDisplay.visiblePosition ?? Offset.zero;

    final size = primaryDisplay.visibleSize ?? primaryDisplay.size;

    /*
   * 저장된 크기는 유지하되
   * 현재 모니터보다 크다면 보정
   */
    final width = savedBounds.width
        .clamp(
          320.0,
          size.width,
        )
        .toDouble();

    final height = savedBounds.height
        .clamp(
          230.0,
          size.height,
        )
        .toDouble();

    /*
   * 메인 모니터 가운데로 이동
   */
    final x = position.dx + (size.width - width) / 2;

    final y = position.dy + (size.height - height) / 2;

    return Rect.fromLTWH(
      x,
      y,
      width,
      height,
    );
  }
}
