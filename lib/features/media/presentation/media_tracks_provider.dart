import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../domain/media_tile.dart';
import '../domain/media_track_type.dart';
import 'media_room_provider.dart';

final mediaTrackRevisionProvider =
    NotifierProvider<MediaTrackRevisionController, int>(
  MediaTrackRevisionController.new,
);

class MediaTrackRevisionController extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void refresh() {
    state++;
  }
}

final mediaTracksProvider = Provider<List<MediaTile>>(
  (ref) {
    /*
     * Track 변경 시 재계산
     */
    ref.watch(
      mediaTrackRevisionProvider,
    );

    final roomAsync = ref.watch(
      mediaRoomProvider,
    );

    final room = roomAsync.value;

    if (room == null) {
      return const [];
    }

    final tiles = <MediaTile>[];

    /*
     * =========================
     * 1. 내 Track
     * =========================
     */
    final localParticipant = room.localParticipant;

    if (localParticipant != null) {
      for (final publication in localParticipant.videoTrackPublications) {
        final track = publication.track;

        if (track == null ||
      publication.muted) {
          continue;
        }

        /*
         * 내 카메라
         */
        if (publication.source == TrackSource.camera) {
          tiles.add(
            MediaTile(
              id: 'my-camera',
              type: MediaTrackType.myCamera,
              label: '내 카메라',
              track: track,
            ),
          );
        }

        /*
         * 내 화면 공유
         */
        if (publication.source == TrackSource.screenShareVideo) {
          tiles.add(
            MediaTile(
              id: 'my-screen',
              type: MediaTrackType.myScreen,
              label: '내 화면',
              track: track,
            ),
          );
        }
      }
    }

    /*
     * =========================
     * 2. 상대방 Track
     * =========================
     */
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;

        if (track == null ||
        publication.muted) {
          continue;
        }

        /*
         * 상대 카메라
         */
        if (publication.source == TrackSource.camera) {
          tiles.add(
            MediaTile(
              id: 'partner-camera',
              type: MediaTrackType.partnerCamera,
              label: '상대 카메라',
              track: track,
            ),
          );
        }

        /*
         * 상대 화면 공유
         */
        if (publication.source == TrackSource.screenShareVideo) {
          tiles.add(
            MediaTile(
              id: 'partner-screen',
              type: MediaTrackType.partnerScreen,
              label: '상대 화면',
              track: track,
            ),
          );
        }
      }
    }

    return tiles;
  },
);
