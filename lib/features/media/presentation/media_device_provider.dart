import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaDeviceState {
  final List<MediaDeviceInfo> cameras;
  final List<MediaDeviceInfo> microphones;
  final List<MediaDeviceInfo> speakers;

  final String? selectedCameraId;
  final String? selectedMicrophoneId;
  final String? selectedSpeakerId;

  final bool loading;

  const MediaDeviceState({
    this.cameras = const [],
    this.microphones = const [],
    this.speakers = const [],
    this.selectedCameraId,
    this.selectedMicrophoneId,
    this.selectedSpeakerId,
    this.loading = false,
  });

  MediaDeviceState copyWith({
    List<MediaDeviceInfo>? cameras,
    List<MediaDeviceInfo>? microphones,
    List<MediaDeviceInfo>? speakers,
    String? selectedCameraId,
    String? selectedMicrophoneId,
    String? selectedSpeakerId,
    bool? loading,
  }) {
    return MediaDeviceState(
      cameras: cameras ?? this.cameras,
      microphones: microphones ?? this.microphones,
      speakers: speakers ?? this.speakers,
      selectedCameraId: selectedCameraId ?? this.selectedCameraId,
      selectedMicrophoneId: selectedMicrophoneId ?? this.selectedMicrophoneId,
      selectedSpeakerId: selectedSpeakerId ?? this.selectedSpeakerId,
      loading: loading ?? this.loading,
    );
  }
}

final mediaDeviceProvider =
    NotifierProvider<MediaDeviceController, MediaDeviceState>(
  MediaDeviceController.new,
);

class MediaDeviceController extends Notifier<MediaDeviceState> {
  @override
  MediaDeviceState build() {
    return const MediaDeviceState();
  }

  Future<void> loadDevices() async {
    state = state.copyWith(
      loading: true,
    );

    final devices = await mediaDevices.enumerateDevices();

    final cameras = devices
        .where(
          (device) => device.kind == 'videoinput',
        )
        .toList();

    final microphones = devices
        .where(
          (device) => device.kind == 'audioinput',
        )
        .toList();

    final speakers = devices
        .where(
          (device) => device.kind == 'audiooutput',
        )
        .toList();

    state = MediaDeviceState(
      cameras: cameras,
      microphones: microphones,
      speakers: speakers,
      selectedCameraId: state.selectedCameraId ??
          (cameras.isNotEmpty ? cameras.first.deviceId : null),
      selectedMicrophoneId: state.selectedMicrophoneId ??
          (microphones.isNotEmpty ? microphones.first.deviceId : null),
      selectedSpeakerId: state.selectedSpeakerId ??
          (speakers.isNotEmpty ? speakers.first.deviceId : null),
      loading: false,
    );
  }

  void selectCamera(
    String deviceId,
  ) {
    state = state.copyWith(
      selectedCameraId: deviceId,
    );
  }

  void selectMicrophone(
    String deviceId,
  ) {
    state = state.copyWith(
      selectedMicrophoneId: deviceId,
    );
  }

  void selectSpeaker(
    String deviceId,
  ) {
    state = state.copyWith(
      selectedSpeakerId: deviceId,
    );
  }
}
