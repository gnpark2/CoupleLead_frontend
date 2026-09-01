import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/model/notification_settings.dart';
import '../data/notification_settings_storage.dart';

final notificationSettingsStorageProvider =
    Provider<NotificationSettingsStorage>(
  (ref) {
    return NotificationSettingsStorage();
  },
);

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsController, NotificationSettings>(
  NotificationSettingsController.new,
);

class NotificationSettingsController
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final storage = ref.read(
      notificationSettingsStorageProvider,
    );

    return await storage.load() ?? const NotificationSettings();
  }

  Future<void> _update(
    NotificationSettings settings,
  ) async {
    state = AsyncData(
      settings,
    );

    await ref
        .read(
          notificationSettingsStorageProvider,
        )
        .save(
          settings,
        );
  }

  Future<void> setChatNotificationEnabled(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        chatNotificationEnabled: value,
      ),
    );
  }

  Future<void> setSoundEnabled(
    bool value,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      return;
    }

    await _update(
      current.copyWith(
        soundEnabled: value,
      ),
    );
  }
}
