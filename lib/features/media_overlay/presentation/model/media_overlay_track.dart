import 'package:livekit_client/livekit_client.dart';

class MediaOverlayTrack {
  final String id;

  final String participantId;

  final String label;

  final RemoteVideoTrack track;

  final TrackSource source;

  const MediaOverlayTrack({
    required this.id,
    required this.participantId,
    required this.label,
    required this.track,
    required this.source,
  });

  bool get isScreenShare => source == TrackSource.screenShareVideo;

  bool get isCamera => source == TrackSource.camera;
}
