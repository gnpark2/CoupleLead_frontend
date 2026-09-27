import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'media_overlay_room_provider.dart';
import 'model/media_overlay_track.dart';

final mediaOverlayTracksProvider = Provider<List<MediaOverlayTrack>>(
  (
    ref,
  ) {
    ref.watch(
      mediaOverlayTrackVersionProvider,
    );

    final roomAsync = ref.watch(
      mediaOverlayRoomProvider,
    );

    final room = roomAsync.valueOrNull;

    final removedIds = ref.watch(
      mediaOverlayRemovedTrackIdsProvider,
    );

    if (room == null) {
      return const [];
    }

    final result = <MediaOverlayTrack>[];

    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;

        if (removedIds.contains(
          publication.sid,
        )) {
          continue;
        }

        if (!publication.subscribed) {
          continue;
        }

        if (track == null) {
          continue;
        }

        if (publication.muted) {
          continue;
        }

        result.add(
          MediaOverlayTrack(
            id: publication.sid,
            participantId: participant.identity,
            label: participant.name.isNotEmpty
                ? participant.name
                : participant.identity,
            track: track,

            /*
             * 아래 필드는 추가할 예정
             */
            source: publication.source,
          ),
        );
      }
    }

    debugPrint(
      '[MEDIA OVERLAY] '
      'active tracks=${result.length} '
      'ids=${result.map((e) => e.id).toList()}',
    );
    return result;
  },
);

final mediaOverlayTrackVersionProvider = StateProvider<int>(
  (
    ref,
  ) =>
      0,
);
