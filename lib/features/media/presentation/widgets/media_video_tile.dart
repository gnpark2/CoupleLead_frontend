import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class MediaVideoTile extends StatelessWidget {
  final Track track;

  final String label;

  final bool main;

  final VoidCallback onSelectMain;

  final VoidCallback onHide;

  const MediaVideoTile({
    super.key,
    required this.track,
    required this.label,
    required this.main,
    required this.onSelectMain,
    required this.onHide,
  });

  Widget _buildVideo() {
    if (track is LocalVideoTrack) {
      return VideoTrackRenderer(
        track as LocalVideoTrack,
      );
    }

    if (track is RemoteVideoTrack) {
      return VideoTrackRenderer(
        track as RemoteVideoTrack,
      );
    }

    return const Center(
      child: Text(
        '영상을 표시할 수 없습니다.',
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        12,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideo(),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Text(
                label,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'main') {
                  onSelectMain();

                  return;
                }

                if (value == 'hide') {
                  onHide();
                }
              },
              itemBuilder: (context) {
                return [
                  if (!main)
                    const PopupMenuItem(
                      value: 'main',
                      child: Text(
                        '메인으로 보기',
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'hide',
                    child: Text(
                      '숨기기',
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }
}
