import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'media_overlay_provider.dart';

final mediaOverlayRoomProvider =
    AsyncNotifierProvider<MediaOverlayRoomController, Room?>(
  MediaOverlayRoomController.new,
);

final mediaOverlayRemovedTrackIdsProvider = StateProvider<Set<String>>(
  (
    ref,
  ) =>
      <String>{},
);

final mediaOverlayTrackVersionProvider = StateProvider<int>(
  (
    ref,
  ) =>
      0,
);

class MediaOverlayRoomController extends AsyncNotifier<Room?> {
  Room? _room;

  EventsListener<RoomEvent>? _roomListener;

  @override
  Future<Room?> build() async {
    ref.onDispose(
      () {
        _disposeRoom();
      },
    );

    return null;
  }

  void _disposeRoom() {
    final listener = _roomListener;

    _roomListener = null;

    listener?.dispose();

    final room = _room;

    _room = null;

    if (room != null) {
      room.disconnect();
      room.dispose();
    }
  }

  Future<bool> connect() async {
    if (_room != null) {
      return true;
    }

    ref
        .read(
          mediaOverlayRemovedTrackIdsProvider.notifier,
        )
        .state = <String>{};

    state = const AsyncLoading();

    try {
      final tokenResponse = await ref
          .read(
            mediaOverlayApiProvider,
          )
          .getToken();

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await room.connect(
        tokenResponse.url,
        tokenResponse.token,
        connectOptions: const ConnectOptions(
          /*
           * 서버 token 자체가 subscribe-only지만
           * Client도 자동 subscribe.
           */
          autoSubscribe: true,
        ),
      );

      _room = room;

/*
 * =====================================
 * Overlay Room 전용 Event Listener
 * =====================================
 */
      _roomListener = room.createListener();

      _roomListener!
        ..on<TrackSubscribedEvent>(
          (
            event,
          ) {
            final sid = event.publication.sid;

            debugPrint(
              '[MEDIA OVERLAY] '
              'track subscribed '
              '$sid',
            );

            /*
       * 같은 SID가 다시 subscribe되었으면
       * removed 목록에서 제거
       */
            final removedNotifier = ref.read(
              mediaOverlayRemovedTrackIdsProvider.notifier,
            );

            removedNotifier.state = {
              ...removedNotifier.state,
            }..remove(
                sid,
              );

            _refreshTracks();
          },
        )
        ..on<TrackUnsubscribedEvent>(
          (
            event,
          ) {
            final sid = event.publication.sid;

            debugPrint(
              '[MEDIA OVERLAY] '
              'track unsubscribed '
              '$sid',
            );

            /*
       * 중요:
       * remove가 아니라 ADD
       */
            final removedNotifier = ref.read(
              mediaOverlayRemovedTrackIdsProvider.notifier,
            );

            removedNotifier.state = {
              ...removedNotifier.state,
              sid,
            };

            _refreshTracks();
          },
        )
        ..on<TrackPublishedEvent>(
          (
            event,
          ) {
            final sid = event.publication.sid;

            debugPrint(
              '[MEDIA OVERLAY] '
              'track published '
              '$sid',
            );

            _refreshTracks();
          },
        )
        ..on<TrackUnpublishedEvent>(
          (
            event,
          ) {
            final sid = event.publication.sid;

            debugPrint(
              '[MEDIA OVERLAY] '
              'track unpublished '
              '$sid',
            );

            /*
       * publication 자체가 Room collection에
       * 잠시 남더라도 Overlay에서는 즉시 제거.
       */
            final removedNotifier = ref.read(
              mediaOverlayRemovedTrackIdsProvider.notifier,
            );

            removedNotifier.state = {
              ...removedNotifier.state,
              sid,
            };

            _refreshTracks();
          },
        )
        ..on<ParticipantDisconnectedEvent>(
          (
            event,
          ) {
            debugPrint(
              '[MEDIA OVERLAY] '
              'participant disconnected '
              '${event.participant.identity}',
            );

            _refreshTracks();
          },
        )
        ..on<TrackMutedEvent>(
          (
            event,
          ) {
            final sid = event.publication.sid;

            debugPrint(
              '[MEDIA OVERLAY] '
              'track muted '
              '$sid',
            );

            /*
     * 카메라 OFF처럼 publication은 남아 있지만
     * 영상 전송만 중지된 경우 즉시 UI에서 제거.
     */
            final removedNotifier = ref.read(
              mediaOverlayRemovedTrackIdsProvider.notifier,
            );

            removedNotifier.state = {
              ...removedNotifier.state,
              sid,
            };

            _refreshTracks();
          },
        )
        ..on<TrackUnmutedEvent>(
          (
            event,
          ) {
            final sid = event.publication.sid;

            debugPrint(
              '[MEDIA OVERLAY] '
              'track unmuted '
              '$sid',
            );

            /*
     * 다시 켜졌으면 다시 표시 가능하도록 복구.
     */
            final removedNotifier = ref.read(
              mediaOverlayRemovedTrackIdsProvider.notifier,
            );

            removedNotifier.state = {
              ...removedNotifier.state,
            }..remove(
                sid,
              );

            _refreshTracks();
          },
        );

      _refreshTracks();

      state = AsyncData(
        room,
      );

      debugPrint(
        '[MEDIA OVERLAY] '
        'LiveKit connected '
        'room=${room.name}',
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[MEDIA OVERLAY] '
        'connect failed: $e',
      );

      state = AsyncError(
        e,
        stackTrace,
      );

      return false;
    }
  }

  void _refreshTracks() {
    final notifier = ref.read(
      mediaOverlayTrackVersionProvider.notifier,
    );

    notifier.state++;

    debugPrint(
      '[MEDIA OVERLAY] '
      'track version=${notifier.state}',
    );
  }

  Future<void> disconnect() async {
    final room = _room;

    _room = null;

    /*
   * Listener부터 정리
   */
    final listener = _roomListener;

    _roomListener = null;

    if (listener != null) {
      await listener.dispose();
    }

    if (room != null) {
      try {
        await room.disconnect();
      } catch (e) {
        debugPrint(
          '[MEDIA OVERLAY] '
          'disconnect error=$e',
        );
      }

      await room.dispose();
    }

    /*
   * 이전 session의 removed track SID 제거
   */
    ref
        .read(
          mediaOverlayRemovedTrackIdsProvider.notifier,
        )
        .state = <String>{};

    state = const AsyncData(
      null,
    );
  }

  Future<void> pauseSubscriptions() async {
    final room = _room;

    if (room == null) {
      return;
    }

    debugPrint(
      '[MEDIA OVERLAY] '
      'pause subscriptions',
    );

    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (!publication.subscribed) {
          continue;
        }

        try {
          await publication.unsubscribe();

          debugPrint(
            '[MEDIA OVERLAY] '
            'unsubscribed ${publication.sid}',
          );
        } catch (e) {
          debugPrint(
            '[MEDIA OVERLAY] '
            'unsubscribe failed '
            '${publication.sid}: $e',
          );
        }
      }
    }

    _refreshTracks();
  }

  Future<bool> resumeSubscriptions() async {
    final room = _room;

    if (room == null) {
      /*
     * 정말 Room이 없다면 새로 연결
     */
      return connect();
    }

    debugPrint(
      '[MEDIA OVERLAY] '
      'resume subscriptions',
    );

    /*
   * 이전 pause 상태 초기화
   */
    ref
        .read(
          mediaOverlayRemovedTrackIdsProvider.notifier,
        )
        .state = <String>{};

    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (publication.subscribed) {
          continue;
        }

        try {
          await publication.subscribe();

          debugPrint(
            '[MEDIA OVERLAY] '
            'subscribed ${publication.sid}',
          );
        } catch (e) {
          debugPrint(
            '[MEDIA OVERLAY] '
            'subscribe failed '
            '${publication.sid}: $e',
          );
        }
      }
    }

    _refreshTracks();

    return true;
  }
}
