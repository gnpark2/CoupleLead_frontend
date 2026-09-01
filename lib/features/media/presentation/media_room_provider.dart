import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/media_api.dart';
import 'media_device_provider.dart';
import 'media_layout_provider.dart';
import 'media_provider.dart';
import 'media_tracks_provider.dart';

final mediaRoomProvider = AsyncNotifierProvider<MediaRoomController, Room?>(
  MediaRoomController.new,
);

class MediaRoomController extends AsyncNotifier<Room?> {
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  @override
  Future<Room?> build() async {
    ref.onDispose(
      _disposeRoom,
    );

    return null;
  }

  Future<bool> connect({
    required String url,
    required String token,
  }) async {
    state = const AsyncLoading();

    try {
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await room.connect(
        url,
        token,
      );

      _room = room;

      /*
     * Room 이벤트 Listener
     */
      _roomListener = room.createListener();

      _roomListener!
        ..on<ParticipantConnectedEvent>(
          (_) {
            _refreshTracks();
          },
        )
        ..on<ParticipantDisconnectedEvent>(
          (_) {
            _refreshTracks();
          },
        )
        ..on<TrackSubscribedEvent>(
          (_) {
            _refreshTracks();
          },
        )
        ..on<TrackUnsubscribedEvent>(
          (_) {
            _refreshTracks();
          },
        )
        ..on<LocalTrackPublishedEvent>(
          (_) {
            _refreshTracks();
          },
        )
        ..on<LocalTrackUnpublishedEvent>(
          (_) {
            _refreshTracks();
          },
        )
        ..on<TrackMutedEvent>(
          (_) {
            debugPrint(
              '[MEDIA] Track muted',
            );

            _refreshTracks();
          },
        )
        ..on<TrackUnmutedEvent>(
          (_) {
            debugPrint(
              '[MEDIA] Track unmuted',
            );

            _refreshTracks();
          },
        );

      /*
     * 최초 상태 갱신
     */
      _refreshTracks();

      state = AsyncData(
        room,
      );

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  Future<bool> join() async {
    try {
      final credentials = await ref
          .read(
            mediaApiProvider,
          )
          .createToken();

      return await connect(
        url: credentials.url,
        token: credentials.token,
      );
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  Future<void> enableCamera({
    required String deviceId,
  }) async {
    final room = _room;

    if (room == null) {
      return;
    }

    final devices = await mediaDevices.enumerateDevices();

    final matches = devices.where(
      (device) => device.kind == 'videoinput' && device.deviceId == deviceId,
    );

    if (matches.isEmpty) {
      throw Exception(
        '선택한 카메라를 찾을 수 없습니다.',
      );
    }

    final selected = matches.first;

    /*
   * 선택된 카메라를
   * LiveKit 기본 video input으로 변경
   */
    await room.setVideoInputDevice(
      MediaDevice(
        selected.deviceId,
        selected.label,
        selected.kind!,
        selected.groupId,
      ),
    );

    /*
   * 실제 카메라 Track publish
   */
    await room.localParticipant?.setCameraEnabled(
      true,
    );

    _refreshTracks();
  }

  Future<void> disableCamera() async {
    final room = _room;

    if (room == null) {
      return;
    }

    await room.localParticipant?.setCameraEnabled(
      false,
    );

    _refreshTracks();
  }

  Future<void> enableMicrophone() async {
    final room = _room;

    if (room == null) {
      return;
    }

    await room.localParticipant?.setMicrophoneEnabled(
      true,
    );
  }

  Future<void> disableMicrophone() async {
    final room = _room;

    if (room == null) {
      return;
    }

    await room.localParticipant?.setMicrophoneEnabled(
      false,
    );
  }

  Future<void> startScreenShare({
    bool shareAudio = true,
    String? sourceId,
  }) async {
    final room = _room;

    if (room == null) {
      return;
    }

    await room.localParticipant?.setScreenShareEnabled(
      true,
      captureScreenAudio: shareAudio,
      screenShareCaptureOptions: ScreenShareCaptureOptions(
        sourceId: sourceId,
        captureScreenAudio: shareAudio,
      ),
    );

    _refreshTracks();
  }

  Future<void> stopScreenShare() async {
    final room = _room;

    if (room == null) {
      return;
    }

    await room.localParticipant?.setScreenShareEnabled(
      false,
    );

    _refreshTracks();
  }

  Future<void> disconnect() async {
    final room = _room;

    if (room == null) {
      return;
    }

    await _roomListener?.dispose();

    _roomListener = null;

    await room.disconnect();

    _room = null;

    ref
        .read(
          mediaLayoutProvider.notifier,
        )
        .reset();

    _refreshTracks();

    state = const AsyncData(null);
  }

  Future<void> _disposeRoom() async {
    await _roomListener?.dispose();

    _roomListener = null;

    await _room?.disconnect();

    await _room?.dispose();

    _room = null;
  }

  void _refreshTracks() {
    ref
        .read(
          mediaTrackRevisionProvider.notifier,
        )
        .refresh();
  }

  Future<void> applyDevices() async {
    final room = _room;

    if (room == null) {
      return;
    }

    final deviceState = ref.read(
      mediaDeviceProvider,
    );

    final devices = await mediaDevices.enumerateDevices();

    /*
   * 카메라
   */
    final camera = _findDevice(
      devices: devices,
      deviceId: deviceState.selectedCameraId,
      kind: 'videoinput',
    );

    if (camera != null) {
      await room.setVideoInputDevice(
        _toLiveKitDevice(
          camera,
        ),
      );
    }

    /*
   * 마이크
   */
    final microphone = _findDevice(
      devices: devices,
      deviceId: deviceState.selectedMicrophoneId,
      kind: 'audioinput',
    );

    if (microphone != null) {
      await room.setAudioInputDevice(
        _toLiveKitDevice(
          microphone,
        ),
      );
    }

    /*
   * 출력 장치
   */
    final speaker = _findDevice(
      devices: devices,
      deviceId: deviceState.selectedSpeakerId,
      kind: 'audiooutput',
    );

    if (speaker != null) {
      await room.setAudioOutputDevice(
        _toLiveKitDevice(
          speaker,
        ),
      );
    }
  }

  MediaDeviceInfo? _findDevice({
    required List<MediaDeviceInfo> devices,
    required String? deviceId,
    required String kind,
  }) {
    if (deviceId == null) {
      return null;
    }

    for (final device in devices) {
      if (device.deviceId == deviceId && device.kind == kind) {
        return device;
      }
    }

    return null;
  }

  MediaDevice _toLiveKitDevice(
    MediaDeviceInfo device,
  ) {
    return MediaDevice(
      device.deviceId,
      device.label,
      device.kind!,
      device.groupId,
    );
  }
}
