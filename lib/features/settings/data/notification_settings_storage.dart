import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'model/notification_settings.dart';

class NotificationSettingsStorage {
  static const _key = 'notification_settings';

  Future<NotificationSettings?> load() async {
    final preferences = await SharedPreferences.getInstance();

    final value = preferences.getString(
      _key,
    );

    if (value == null) {
      return null;
    }

    try {
      final json = jsonDecode(value) as Map<String, dynamic>;

      return NotificationSettings.fromJson(
        json,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
    NotificationSettings settings,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _key,
      jsonEncode(
        settings.toJson(),
      ),
    );
  }
}
