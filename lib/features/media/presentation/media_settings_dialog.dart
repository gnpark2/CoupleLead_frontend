import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'media_device_provider.dart';
import 'media_room_provider.dart';

class MediaSettingsDialog extends ConsumerStatefulWidget {
  const MediaSettingsDialog({
    super.key,
  });

  @override
  ConsumerState<MediaSettingsDialog> createState() =>
      _MediaSettingsDialogState();
}

class _MediaSettingsDialogState extends ConsumerState<MediaSettingsDialog> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        ref
            .read(
              mediaDeviceProvider.notifier,
            )
            .loadDevices();
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final state = ref.watch(
      mediaDeviceProvider,
    );

    return AlertDialog(
      title: const Text(
        '미디어 설정',
      ),
      content: SizedBox(
        width: 500,
        child: state.loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /*
                   * 카메라
                   */
                  DropdownButtonFormField<String>(
                    value: state.selectedCameraId,
                    decoration: const InputDecoration(
                      labelText: '카메라',
                      border: OutlineInputBorder(),
                    ),
                    items: state.cameras.map(
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

                      ref
                          .read(
                            mediaDeviceProvider.notifier,
                          )
                          .selectCamera(
                            value,
                          );
                    },
                  ),
                  const SizedBox(
                    height: 16,
                  ),

                  /*
                   * 마이크
                   */
                  DropdownButtonFormField<String>(
                    value: state.selectedMicrophoneId,
                    decoration: const InputDecoration(
                      labelText: '마이크',
                      border: OutlineInputBorder(),
                    ),
                    items: state.microphones.map(
                      (device) {
                        return DropdownMenuItem(
                          value: device.deviceId,
                          child: Text(
                            device.label.isEmpty ? '마이크' : device.label,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      ref
                          .read(
                            mediaDeviceProvider.notifier,
                          )
                          .selectMicrophone(
                            value,
                          );
                    },
                  ),
                  const SizedBox(
                    height: 16,
                  ),

                  /*
                   * 출력 장치
                   */
                  DropdownButtonFormField<String>(
                    value: state.selectedSpeakerId,
                    decoration: const InputDecoration(
                      labelText: '소리 출력 장치',
                      border: OutlineInputBorder(),
                    ),
                    items: state.speakers.map(
                      (device) {
                        return DropdownMenuItem(
                          value: device.deviceId,
                          child: Text(
                            device.label.isEmpty ? '스피커' : device.label,
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      ref
                          .read(
                            mediaDeviceProvider.notifier,
                          )
                          .selectSpeaker(
                            value,
                          );
                    },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            '취소',
          ),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(
                  mediaRoomProvider.notifier,
                )
                .applyDevices();

            if (!context.mounted) {
              return;
            }

            Navigator.of(context).pop();
          },
          child: const Text(
            '적용',
          ),
        ),
      ],
    );
  }
}
