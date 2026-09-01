import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OverlayWindowStorage {
  const OverlayWindowStorage._();

  static const String _xKey = 'overlay_window_x';

  static const String _yKey = 'overlay_window_y';

  static const String _widthKey = 'overlay_window_width';

  static const String _heightKey = 'overlay_window_height';

  static Future<void> saveBounds(
    Rect bounds,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setDouble(
      _xKey,
      bounds.left,
    );

    await preferences.setDouble(
      _yKey,
      bounds.top,
    );

    await preferences.setDouble(
      _widthKey,
      bounds.width,
    );

    await preferences.setDouble(
      _heightKey,
      bounds.height,
    );
  }

  static Future<Rect?> loadBounds() async {
    final preferences = await SharedPreferences.getInstance();

    final x = preferences.getDouble(_xKey);

    final y = preferences.getDouble(_yKey);

    final width = preferences.getDouble(_widthKey);

    final height = preferences.getDouble(_heightKey);

    if (x == null || y == null || width == null || height == null) {
      return null;
    }

    /*
     * 혹시 과거에 잘못된 값이 저장되어 있더라도
     * 최소 크기보다 작아지지 않도록 보정
     */
    final safeWidth = width < 320 ? 320.0 : width;

    final safeHeight = height < 230 ? 230.0 : height;

    return Rect.fromLTWH(
      x,
      y,
      safeWidth,
      safeHeight,
    );
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_xKey);
    await preferences.remove(_yKey);
    await preferences.remove(_widthKey);
    await preferences.remove(_heightKey);
  }
}
