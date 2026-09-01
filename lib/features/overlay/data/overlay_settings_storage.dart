import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'model/overlay_settings.dart';

class OverlaySettingsStorage {
  static const String _key = 'overlay_settings';

  Future<OverlaySettings?> load() async {
    final preferences = await SharedPreferences.getInstance();

    final value = preferences.getString(
      _key,
    );

    if (value == null) {
      return null;
    }

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;

      return OverlaySettings.fromJson(
        json,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    OverlaySettings settings,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    final value = jsonEncode(
      settings.toJson(),
    );

    await preferences.setString(
      _key,
      value,
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(
      _key,
    );
  }
}
