import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/desktop/desktop_media_overlay_window_service.dart';
import '../data/model/media_overlay_settings.dart';
import 'media_overlay_room_provider.dart';
import 'media_overlay_tracks_provider.dart';
import 'model/media_overlay_track.dart';
import 'overlay_settings_provider.dart';

class MediaOverlayPage extends ConsumerStatefulWidget {
  final String mainWindowId;

  const MediaOverlayPage({
    super.key,
    required this.mainWindowId,
  });

  @override
  ConsumerState<MediaOverlayPage> createState() => _MediaOverlayPageState();
}

class _MediaOverlayPageState extends ConsumerState<MediaOverlayPage> {
  Future<void> _returnToMediaPage() async {
    /*
   * 1. Overlay 전용 subscribe-only Room 종료
   *
   * 메인 MediaRoom은 건드리지 않는다.
   */
    await ref
        .read(
          mediaOverlayRoomProvider.notifier,
        )
        .disconnect();

    /*
   * 2. Main Engine에
   * overlay 종료 알림
   */
    try {
      final mainWindow = WindowController.fromWindowId(
        widget.mainWindowId,
      );

      await mainWindow.invokeMethod(
        'media_overlay_closed',
      );
    } catch (e) {
      debugPrint(
        '[MEDIA OVERLAY] '
        'notify main failed: $e',
      );
    }

    /*
   * 3. Overlay window는 죽이지 않고 숨김
   */
    await windowManager.hide();
  }

  Future<void> _closeOverlay() async {
    debugPrint(
      '[MEDIA OVERLAY] '
      'close button pressed',
    );

    /*
   * ==================================
   * 1. 영상 subscription만 중단
   * ==================================
   *
   * Room 자체는 dispose하지 않는다.
   */
    await ref
        .read(
          mediaOverlayRoomProvider.notifier,
        )
        .pauseSubscriptions();

    /*
   * ==================================
   * 2. Overlay 창 먼저 숨김
   * ==================================
   */
    await windowManager.hide();

    debugPrint(
      '[MEDIA OVERLAY] '
      'window hidden',
    );

    /*
   * ==================================
   * 3. Main Renderer 복원
   * ==================================
   *
   * Overlay renderer가 화면에서 제거된 뒤
   * Main renderer를 다시 붙인다.
   */
    try {
      final mainWindow = WindowController.fromWindowId(
        widget.mainWindowId,
      );

      final result = await mainWindow.invokeMethod(
        'media_overlay_closed',
      );

      debugPrint(
        '[MEDIA OVERLAY] '
        'media_overlay_closed '
        'result=$result',
      );
    } catch (e) {
      debugPrint(
        '[MEDIA OVERLAY] '
        'notify main failed=$e',
      );
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (
        _,
      ) {
        ref
            .read(
              mediaOverlayRoomProvider.notifier,
            )
            .connect();
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final roomAsync = ref.watch(
      mediaOverlayRoomProvider,
    );

    final tracks = ref.watch(
      mediaOverlayTracksProvider,
    );

    final settings = ref.watch(
      mediaOverlaySettingsProvider,
    );

    ref.listen<List<MediaOverlayTrack>>(
      mediaOverlayTracksProvider,
      (
        previous,
        next,
      ) {
        final settings = ref.read(
          mediaOverlaySettingsProvider,
        );

        final currentMainTrackId = settings.mainTrackId;

        /*
     * mainTrackId가 없으면 할 일 없음
     */
        if (currentMainTrackId == null) {
          return;
        }

        final exists = next.any(
          (
            track,
          ) =>
              track.id == currentMainTrackId,
        );

        /*
     * 현재 main track이 아직 존재함
     */
        if (exists) {
          return;
        }

        /*
     * main track이 공유 종료 등으로 사라짐
     */
        final controller = ref.read(
          mediaOverlaySettingsProvider.notifier,
        );

        if (next.isEmpty) {
          controller.clearMainTrack();

          debugPrint(
            '[MEDIA OVERLAY] '
            'main track removed -> cleared',
          );

          return;
        }

        /*
     * 남아있는 첫 번째 track을 새 main으로
     */
        controller.setMainTrack(
          next.first.id,
        );

        debugPrint(
          '[MEDIA OVERLAY] '
          'main track removed -> fallback=${next.first.id}',
        );
      },
    );

    return DragToResizeArea(
      resizeEdgeSize: 8,
      resizeEdgeColor: Colors.transparent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            _Header(
              onClose: _closeOverlay,
            ),
            Expanded(
              child: roomAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (
                  error,
                  stackTrace,
                ) =>
                    Center(
                  child: Text(
                    '화면 공유 연결 실패\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
                data: (
                  room,
                ) {
                  if (room == null) {
                    return const Center(
                      child: Text(
                        'LiveKit 연결 대기 중',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  if (tracks.isEmpty) {
                    return const Center(
                      child: Text(
                        '현재 공유 중인 화면이 없습니다.',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  return _MediaOverlayLayout(
                    tracks: tracks,
                    settings: settings,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({
    required this.onClose,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (
        _,
      ) {
        windowManager.startDragging();
      },
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.screen_share,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(
                width: 8,
              ),
              const Expanded(
                child: Text(
                  '화면 공유',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                tooltip: '오버레이 닫기',
                onPressed: onClose,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaOverlayLayout extends ConsumerWidget {
  final List<MediaOverlayTrack> tracks;

  final MediaOverlaySettings settings;

  const _MediaOverlayLayout({
    required this.tracks,
    required this.settings,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    debugPrint(
      '[MEDIA OVERLAY] '
      'layout=${settings.layout} '
      'tracks=${tracks.length} '
      'ids=${tracks.map((e) => e.id).toList()}',
    );
    switch (settings.layout) {
      case MediaOverlayLayout.equal:
        return _EqualLayout(
          tracks: tracks,
        );

      case MediaOverlayLayout.mainOnly:
        return _MainOnlyLayout(
          tracks: tracks,
          mainTrackId: settings.mainTrackId,
        );

      case MediaOverlayLayout.mainWithThumbnails:
        return _MainWithThumbnailsLayout(
          tracks: tracks,
          mainTrackId: settings.mainTrackId,
        );
    }
  }
}

class _ScreenTile extends StatelessWidget {
  final MediaOverlayTrack track;

  final VoidCallback? onTap;

  const _ScreenTile({
    required this.track,
    this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          8,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoTrackRenderer(
              track.track,
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(
                    6,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    track.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EqualLayout extends StatelessWidget {
  final List<MediaOverlayTrack> tracks;

  const _EqualLayout({
    required this.tracks,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final columns = tracks.length <= 1
        ? 1
        : tracks.length <= 4
            ? 2
            : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(
        8,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: tracks.length,
      itemBuilder: (
        context,
        index,
      ) {
        return _ScreenTile(
          track: tracks[index],
        );
      },
    );
  }
}

MediaOverlayTrack _mainTrack(
  List<MediaOverlayTrack> tracks,
  String? mainTrackId,
) {
  if (mainTrackId != null) {
    for (final track in tracks) {
      if (track.id == mainTrackId) {
        return track;
      }
    }
  }

  return tracks.first;
}

class _MainOnlyLayout extends ConsumerWidget {
  final List<MediaOverlayTrack> tracks;

  final String? mainTrackId;

  const _MainOnlyLayout({
    required this.tracks,
    required this.mainTrackId,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final main = _mainTrack(
      tracks,
      mainTrackId,
    );

    return Padding(
      padding: const EdgeInsets.all(
        8,
      ),
      child: _ScreenTile(
        track: main,
      ),
    );
  }
}

class _MainWithThumbnailsLayout extends ConsumerWidget {
  final List<MediaOverlayTrack> tracks;

  final String? mainTrackId;

  const _MainWithThumbnailsLayout({
    required this.tracks,
    required this.mainTrackId,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final main = _mainTrack(
      tracks,
      mainTrackId,
    );

    final others = tracks
        .where(
          (
            track,
          ) =>
              track.id != main.id,
        )
        .toList();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(
              8,
            ),
            child: _ScreenTile(
              track: main,
            ),
          ),
        ),
        if (others.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                8,
                0,
                8,
                8,
              ),
              itemCount: others.length,
              separatorBuilder: (
                _,
                __,
              ) =>
                  const SizedBox(
                width: 8,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                final track = others[index];

                return SizedBox(
                  width: 180,
                  child: _ScreenTile(
                    track: track,
                    onTap: () {
                      ref
                          .read(
                            mediaOverlaySettingsProvider.notifier,
                          )
                          .setMainTrack(
                            track.id,
                          );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
