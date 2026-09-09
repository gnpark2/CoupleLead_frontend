import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/model/media_overlay_settings.dart';

final mediaOverlaySettingsProvider =
    NotifierProvider<MediaOverlaySettingsController, MediaOverlaySettings>(
  MediaOverlaySettingsController.new,
);

class MediaOverlaySettingsController extends Notifier<MediaOverlaySettings> {
  @override
  MediaOverlaySettings build() {
    return const MediaOverlaySettings();
  }

  void setLayout(
    MediaOverlayLayout layout,
  ) {
    state = state.copyWith(
      layout: layout,
    );
  }

  void setMainTrack(
    String trackId,
  ) {
    state = state.copyWith(
      mainTrackId: trackId,
    );
  }

  void apply(
    MediaOverlaySettings settings,
  ) {
    state = settings;
  }

  void clearMainTrack() {
    state = state.copyWith(
      clearMainTrackId: true,
    );
  }
}
