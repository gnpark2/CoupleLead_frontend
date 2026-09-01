import 'package:livekit_client/livekit_client.dart';

import 'media_track_type.dart';

class MediaTile {
  final String id;
  final MediaTrackType type;
  final String label;
  final Track track;

  const MediaTile({
    required this.id,
    required this.type,
    required this.label,
    required this.track,
  });
}
