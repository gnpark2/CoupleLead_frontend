import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/overlay_settings.dart';

class OverlaySettingsStorage {
  static const String _key =
      'overlay_settings';

  final SharedPreferencesAsync _preferences =
      SharedPreferencesAsync();

  Future<OverlaySettings?> load() async {
    final value =
        await _preferences.getString(
      _key,
    );

    debugPrint(
      '[OVERLAY STORAGE] LOAD raw=$value',
    );

    if (value == null) {
      return null;
    }

    try {
      final json =
          jsonDecode(
        value,
      ) as Map<String, dynamic>;

      final settings =
          OverlaySettings.fromJson(
        json,
      );

      debugPrint(
        '[OVERLAY STORAGE] LOAD '
        'showAnniversary='
        '${settings.showAnniversary}, '
        'showMyTime='
        '${settings.showMyTime}, '
        'showPartnerTime='
        '${settings.showPartnerTime}, '
        'showMyWeather='
        '${settings.showMyWeather}, '
        'showPartnerWeather='
        '${settings.showPartnerWeather}',
      );

      return settings;
    } catch (e) {
      debugPrint(
        '[OVERLAY STORAGE] LOAD ERROR $e',
      );

      return null;
    }
  }

  Future<void> save(
    OverlaySettings settings,
  ) async {
    final value =
        jsonEncode(
      settings.toJson(),
    );

    debugPrint(
      '[OVERLAY STORAGE] SAVE raw=$value',
    );

    await _preferences.setString(
      _key,
      value,
    );
  }

  Future<void> clear() async {
    await _preferences.remove(
      _key,
    );
  }
}