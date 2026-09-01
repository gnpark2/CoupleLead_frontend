import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import 'camera_setup_dialog.dart';
import 'media_device_provider.dart';
import 'media_layout_provider.dart';
import 'media_provider.dart';
import 'media_room_provider.dart';
import 'media_settings_dialog.dart';
import 'media_tracks_provider.dart';
import 'screen_select_dialog.dart';
import 'widgets/media_layout.dart';

class MediaRoomPage extends ConsumerStatefulWidget {
  const MediaRoomPage({
    super.key,
  });

  @override
  ConsumerState<MediaRoomPage> createState() => _MediaRoomPageState();
}

class _MediaRoomPageState extends ConsumerState<MediaRoomPage> {
  Future<void> _toggleCamera() async {
    final room = ref
        .read(
          mediaRoomProvider,
        )
        .value;

    if (room == null) {
      return;
    }

    final participant = room.localParticipant;

    if (participant == null) {
      return;
    }

    final enabled = participant.isCameraEnabled();

    final controller = ref.read(
      mediaRoomProvider.notifier,
    );

    /*
   * 이미 켜져 있으면 바로 종료
   */
    if (enabled) {
      await controller.disableCamera();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    /*
   * 카메라 OFF → ON 할 때는
   * 먼저 테스트/선택 Dialog
   */
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        context,
      ) {
        return const CameraSetupDialog();
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final deviceState = ref.read(
      mediaDeviceProvider,
    );

    final cameraId = deviceState.selectedCameraId;

    if (cameraId == null) {
      return;
    }

    await controller.enableCamera(
      deviceId: cameraId,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleMicrophone() async {
    final roomAsync = ref.read(
      mediaRoomProvider,
    );

    final room = roomAsync.value;

    if (room == null) {
      return;
    }

    final participant = room.localParticipant;

    if (participant == null) {
      return;
    }

    final enabled = participant.isMicrophoneEnabled();

    final controller = ref.read(
      mediaRoomProvider.notifier,
    );

    if (enabled) {
      await controller.disableMicrophone();
    } else {
      await controller.enableMicrophone();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleScreenShare() async {
    final roomAsync = ref.read(
      mediaRoomProvider,
    );

    final room = roomAsync.value;

    if (room == null) {
      return;
    }

    final participant = room.localParticipant;

    if (participant == null) {
      return;
    }

    final sharing = participant.isScreenShareEnabled();

    final controller = ref.read(
      mediaRoomProvider.notifier,
    );

    /*
   * 이미 공유 중이면 종료
   */
    if (sharing) {
      await controller.stopScreenShare();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    /*
   * Windows / macOS
   * 공유할 화면 또는 창 선택
   */
    final source = await showDialog<DesktopCapturerSource>(
      context: context,
      builder: (
        context,
      ) {
        return const ScreenSelectDialog();
      },
    );

    if (source == null) {
      return;
    }

    await controller.startScreenShare(
      sourceId: source.id,
      shareAudio: true,
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _joinRoom() async {
    final success = await ref
        .read(
          mediaRoomProvider.notifier,
        )
        .join();

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '미디어 룸 연결에 실패했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _leaveRoom() async {
    try {
      await ref
          .read(
            mediaApiProvider,
          )
          .leave();
    } catch (e) {
      debugPrint(
        '[MEDIA] leave notify failed: $e',
      );
    }

    await ref
        .read(
          mediaRoomProvider.notifier,
        )
        .disconnect();

    if (!mounted) {
      return;
    }

    context.go('/home');
  }

  Future<void> _openMediaSettings() async {
    await showDialog<void>(
      context: context,
      builder: (
        context,
      ) {
        return const MediaSettingsDialog();
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _joinRoom();
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final layoutState = ref.watch(
      mediaLayoutProvider,
    );

    final tiles = ref.watch(
      mediaTracksProvider,
    );

    final roomAsync = ref.watch(
      mediaRoomProvider,
    );

    ref.listen(
      mediaTracksProvider,
      (
        previous,
        next,
      ) {
        final existingTrackIds = next
            .map(
              (tile) => tile.id,
            )
            .toSet();

        ref
            .read(
              mediaLayoutProvider.notifier,
            )
            .removeMissingTracks(
              existingTrackIds,
            );
      },
    );
    /*
   * 숨긴 Track
   */
    final hiddenTiles = tiles.where(
      (tile) {
        return layoutState.hiddenTrackIds.contains(
          tile.id,
        );
      },
    ).toList();

    /*
   * 현재 표시할 Track
   */
    final visibleTiles = tiles.where(
      (tile) {
        return !layoutState.hiddenTrackIds.contains(
          tile.id,
        );
      },
    ).toList();

    return PopScope(
        // onPopInvokedWithResult: (
        //   didPop,
        //   result,
        // ) async {
        //   if (didPop) {
        //     await ref
        //         .read(
        //           mediaRoomProvider.notifier,
        //         )
        //         .disconnect();
        //   }
        // },
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(
              '미디어 공유',
            ),
            actions: [
              /*
              * 미디어 장치 설정
              */
              IconButton(
                tooltip: '미디어 설정',
                icon: const Icon(
                  Icons.settings,
                ),
                onPressed: _openMediaSettings,
              ),
              IconButton(
                tooltip: '미디어 룸 나가기',
                icon: const Icon(
                  Icons.call_end,
                ),
                onPressed: _leaveRoom,
              ),
            ],
          ),
          body: roomAsync.when(
            /*
       * =========================
       * LiveKit 연결 중
       * =========================
       */
            loading: () {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },

            /*
       * =========================
       * 연결 실패
       * =========================
       */
            error: (
              error,
              stackTrace,
            ) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(
                    24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      const Text(
                        '미디어 룸 연결에 실패했습니다.',
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(
                        height: 24,
                      ),
                      FilledButton(
                        onPressed: _joinRoom,
                        child: const Text(
                          '다시 연결',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },

            /*
       * =========================
       * 연결 성공
       * =========================
       */
            data: (room) {
              /*
   * 아직 Room에 연결되지 않은 상태
   */
              if (room == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '미디어 룸에 연결되지 않았습니다.',
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      FilledButton(
                        onPressed: _joinRoom,
                        child: const Text(
                          '연결',
                        ),
                      ),
                    ],
                  ),
                );
              }

              /*
   * room != null 확인 후 사용
   */
              final participant = room.localParticipant;

              final cameraEnabled = participant?.isCameraEnabled() ?? false;

              final microphoneEnabled =
                  participant?.isMicrophoneEnabled() ?? false;

              final screenSharing =
                  participant?.isScreenShareEnabled() ?? false;

              return Column(
                children: [
                  /*
             * =========================
             * 메인 + 사이드 영상
             * =========================
             */
                  Expanded(
                    child: MediaLayout(
                      tiles: visibleTiles,
                    ),
                  ),

                  /*
             * =========================
             * 숨긴 영상 다시 보기
             * =========================
             */
                  if (hiddenTiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hiddenTiles.map(
                          (tile) {
                            return ActionChip(
                              label: Text(
                                '${tile.label} 보기',
                              ),
                              onPressed: () {
                                ref
                                    .read(
                                      mediaLayoutProvider.notifier,
                                    )
                                    .show(
                                      tile.id,
                                    );
                              },
                            );
                          },
                        ).toList(),
                      ),
                    ),

                  /*
             * =========================
             * 미디어 컨트롤
             * =========================
             */
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          /*
                     * 마이크
                     */
                          IconButton.filled(
                            tooltip: microphoneEnabled ? '마이크 끄기' : '마이크 켜기',
                            onPressed: _toggleMicrophone,
                            icon: Icon(
                              microphoneEnabled ? Icons.mic : Icons.mic_off,
                            ),
                          ),

                          /*
                     * 카메라
                     */
                          IconButton.filled(
                            tooltip: cameraEnabled ? '카메라 끄기' : '카메라 켜기',
                            onPressed: _toggleCamera,
                            icon: Icon(
                              cameraEnabled
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                            ),
                          ),

                          /*
                     * 화면 공유
                     */
                          FilledButton.icon(
                            onPressed: _toggleScreenShare,
                            icon: Icon(
                              screenSharing
                                  ? Icons.stop_screen_share
                                  : Icons.screen_share,
                            ),
                            label: Text(
                              screenSharing ? '공유 중지' : '화면 공유',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ));
  }
}
