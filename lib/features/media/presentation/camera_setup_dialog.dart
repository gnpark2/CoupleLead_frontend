import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'media_device_provider.dart';

class CameraSetupDialog extends ConsumerStatefulWidget {
  const CameraSetupDialog({
    super.key,
  });

  @override
  ConsumerState<CameraSetupDialog> createState() => _CameraSetupDialogState();
}

class _CameraSetupDialogState extends ConsumerState<CameraSetupDialog> {
  LocalVideoTrack? _previewTrack;

  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        await ref
            .read(
              mediaDeviceProvider.notifier,
            )
            .loadDevices();

        await _startPreview();
      },
    );
  }

  Future<void> _startPreview() async {
    final deviceState = ref.read(
      mediaDeviceProvider,
    );

    final cameraId = deviceState.selectedCameraId;

    if (cameraId == null) {
      return;
    }

    setState(() {
      _loadingPreview = true;
    });

    /*
     * 기존 preview 정리
     */
    await _previewTrack?.stop();

    await _previewTrack?.dispose();

    try {
      final track = await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(
          deviceId: cameraId,
        ),
      );

      if (!mounted) {
        await track.stop();
        await track.dispose();
        return;
      }

      setState(() {
        _previewTrack = track;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingPreview = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '카메라 미리보기에 실패했습니다.\n$e',
          ),
        ),
      );
    }
  }

  Future<void> _changeCamera(
    String deviceId,
  ) async {
    ref
        .read(
          mediaDeviceProvider.notifier,
        )
        .selectCamera(
          deviceId,
        );

    await _startPreview();
  }

  Future<void> _closePreview() async {
    await _previewTrack?.stop();

    await _previewTrack?.dispose();

    _previewTrack = null;
  }

  @override
  void dispose() {
    /*
     * dispose에서는 await할 수 없으므로
     * 직접 호출
     */
    _previewTrack?.stop();

    _previewTrack?.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final deviceState = ref.watch(
      mediaDeviceProvider,
    );

    return AlertDialog(
      title: const Text(
        '카메라 설정',
      ),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /*
             * 카메라 미리보기
             */
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  12,
                ),
                child: ColoredBox(
                  color: Colors.black,
                  child: _loadingPreview
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _previewTrack != null
                          ? VideoTrackRenderer(
                              _previewTrack!,
                            )
                          : const Center(
                              child: Text(
                                '카메라 화면이 없습니다.',
                              ),
                            ),
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            DropdownButtonFormField<String>(
              value: deviceState.selectedCameraId,
              decoration: const InputDecoration(
                labelText: '카메라',
                border: OutlineInputBorder(),
              ),
              items: deviceState.cameras.map(
                (device) {
                  return DropdownMenuItem(
                    value: device.deviceId,
                    child: Text(
                      device.label.isEmpty ? '카메라' : device.label,
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                _changeCamera(
                  value,
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await _closePreview();

            if (!context.mounted) {
              return;
            }

            Navigator.of(context).pop(false);
          },
          child: const Text(
            '취소',
          ),
        ),
        FilledButton(
          onPressed: () async {
            await _closePreview();

            if (!context.mounted) {
              return;
            }

            Navigator.of(context).pop(true);
          },
          child: const Text(
            '이 카메라 사용',
          ),
        ),
      ],
    );
  }
}
