import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/desktop/desktop_overlay_window_service.dart';
import '../data/model/overlay_settings.dart';
import '../data/overlay_settings_storage.dart';

final overlaySettingsStorageProvider = Provider<OverlaySettingsStorage>(
  (ref) {
    return OverlaySettingsStorage();
  },
);

final overlaySettingsProvider =
    AsyncNotifierProvider<OverlaySettingsController, OverlaySettings>(
  OverlaySettingsController.new,
);

class OverlaySettingsController extends AsyncNotifier<OverlaySettings> {
  @override
  Future<OverlaySettings> build() async {
    final storage = ref.read(
      overlaySettingsStorageProvider,
    );

    final saved = await storage.load();

    return saved ?? const OverlaySettings();
  }

  Future<void> _update(
    OverlaySettings settings,
  ) async {
    /*
   * 1. 현재 Main Window 즉시 반영
   */
    state = AsyncData(
      settings,
    );

    /*
   * 2. 앱 재시작 대비 영속 저장
   */
    await ref
        .read(
          overlaySettingsStorageProvider,
        )
        .save(
          settings,
        );

    /*
   * 3. Overlay Window에는
   *    저장소를 다시 읽으라고 하지 않고
   *    최신 설정값 자체를 전달
   */
    await DesktopOverlayWindowService.instance.applySettings(
      settings,
    );
  }

  Future<void> setAnniversary(
    int? anniversaryId,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    final newSettings = anniversaryId == null
        ? current.copyWith(
            clearAnniversaryId: true,
          )
        : current.copyWith(
            anniversaryId: anniversaryId,
          );

    await _update(
      newSettings,
    );
  }

  Future<void> setShowAnniversary(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        showAnniversary: value,
      ),
    );
  }

  Future<void> setShowMyTime(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        showMyTime: value,
      ),
    );
  }

  Future<void> setShowPartnerTime(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        showPartnerTime: value,
      ),
    );
  }

  Future<void> setShowMyWeather(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        showMyWeather: value,
      ),
    );
  }

  Future<void> setShowPartnerWeather(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        showPartnerWeather: value,
      ),
    );
  }

  Future<void> reload() async {
    debugPrint(
      '[OVERLAY SETTINGS] reload start',
    );

    final storage = ref.read(
      overlaySettingsStorageProvider,
    );

    final loaded = await storage.load();

    final next = loaded ?? const OverlaySettings();

    state = AsyncData(
      next,
    );

    debugPrint(
      '[OVERLAY SETTINGS] reload complete '
      'showAnniversary='
      '${next.showAnniversary}, '
      'showMyTime='
      '${next.showMyTime}, '
      'showPartnerTime='
      '${next.showPartnerTime}, '
      'showMyWeather='
      '${next.showMyWeather}, '
      'showPartnerWeather='
      '${next.showPartnerWeather}',
    );
  }

  void applyExternalSettings(
    OverlaySettings settings,
  ) {
    debugPrint(
      '[OVERLAY SETTINGS] '
      'apply external '
      'showAnniversary=${settings.showAnniversary}, '
      'showMyTime=${settings.showMyTime}, '
      'showPartnerTime=${settings.showPartnerTime}, '
      'showMyWeather=${settings.showMyWeather}, '
      'showPartnerWeather=${settings.showPartnerWeather}',
    );

    state = AsyncData(
      settings,
    );
  }
}
