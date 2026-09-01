import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    OverlaySettings newSettings,
  ) async {
    state = AsyncData(
      newSettings,
    );

    await ref
        .read(
          overlaySettingsStorageProvider,
        )
        .save(
          newSettings,
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
}
