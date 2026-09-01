import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaLayoutState {
  final String? mainTrackId;

  final Set<String> hiddenTrackIds;

  const MediaLayoutState({
    this.mainTrackId,
    this.hiddenTrackIds = const {},
  });

  MediaLayoutState copyWith({
    String? mainTrackId,
    bool clearMainTrackId = false,
    Set<String>? hiddenTrackIds,
  }) {
    return MediaLayoutState(
      mainTrackId: clearMainTrackId ? null : mainTrackId ?? this.mainTrackId,
      hiddenTrackIds: hiddenTrackIds ?? this.hiddenTrackIds,
    );
  }
}

final mediaLayoutProvider =
    NotifierProvider<MediaLayoutController, MediaLayoutState>(
  MediaLayoutController.new,
);

class MediaLayoutController extends Notifier<MediaLayoutState> {
  @override
  MediaLayoutState build() {
    return const MediaLayoutState();
  }

  void selectMain(
    String trackId,
  ) {
    state = state.copyWith(
      mainTrackId: trackId,
    );
  }

  void hide(
    String trackId,
  ) {
    final hidden = Set<String>.from(
      state.hiddenTrackIds,
    );

    hidden.add(
      trackId,
    );

    state = state.copyWith(
      hiddenTrackIds: hidden,
    );
  }

  void show(
    String trackId,
  ) {
    final hidden = Set<String>.from(
      state.hiddenTrackIds,
    );

    hidden.remove(
      trackId,
    );

    state = state.copyWith(
      hiddenTrackIds: hidden,
    );
  }

  void removeMissingTracks(
    Set<String> existingTrackIds,
  ) {
    final cleanedHidden = state.hiddenTrackIds
        .where(
          existingTrackIds.contains,
        )
        .toSet();

    final currentMain = state.mainTrackId;

    final mainExists = currentMain != null &&
        existingTrackIds.contains(
          currentMain,
        );

    state = state.copyWith(
      hiddenTrackIds: cleanedHidden,
      clearMainTrackId: currentMain != null && !mainExists,
    );
  }

  void reset() {
    state = const MediaLayoutState();
  }
}
