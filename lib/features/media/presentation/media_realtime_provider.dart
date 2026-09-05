import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/websocket/stomp_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/media_invite.dart';

final mediaRealtimeProvider = Provider.family<MediaRealtimeController, int>(
  (
    ref,
    userId,
  ) {
    final controller = MediaRealtimeController(
      ref: ref,
      userId: userId,
    );

    ref.onDispose(
      controller.dispose,
    );

    return controller;
  },
);

class MediaRealtimeController {
  final Ref ref;
  final int userId;

  StompUnsubscribe? _unsubscribe;

  bool _subscribed = false;

  MediaRealtimeController({
    required this.ref,
    required this.userId,
  });

  Future<void> start({
    required void Function(
      MediaInvite invite,
    ) onInvite,
    required void Function(
      String callId,
    ) onAccepted,
    required void Function(
      String callId,
    ) onRejected,
    required void Function(
      Map<String, dynamic> data,
    ) onMediaLeft,
  }) async {
    if (_subscribed) {
      return;
    }

    final stomp = ref.read(
      stompServiceProvider,
    );

/*
 * 중요:
 *
 * STOMP 연결 여부와 상관없이
 * logical subscription을 먼저 등록한다.
 *
 * 현재 연결되어 있으면 즉시 실제 subscribe,
 * 연결 전이라면 StompService가 reconnect 후
 * _restoreSubscriptions()에서 자동 복구한다.
 */
    _unsubscribe = stomp.subscribe(
      destination: ApiConstants.mediaUserTopic(
        userId,
      ),
      onMessage: (data) {
        final type = data['type'] as String?;

        debugPrint(
          '[MEDIA-STOMP] EVENT '
          'type=$type data=$data',
        );

        switch (type) {
          case 'MEDIA_INVITE':
            onInvite(
              MediaInvite.fromJson(
                data,
              ),
            );
            break;

          case 'MEDIA_ACCEPTED':
            final callId = data['callId'] as String;

            onAccepted(
              callId,
            );
            break;

          case 'MEDIA_REJECTED':
            final callId = data['callId'] as String;

            onRejected(
              callId,
            );
            break;

          case 'MEDIA_LEFT':
            onMediaLeft(
              data,
            );
            break;

          default:
            debugPrint(
              '[MEDIA-STOMP] unknown event type: $type',
            );
        }
      },
    );

    _subscribed = true;

/*
 * subscription 등록 후
 * STOMP 연결을 보장한다.
 */
    if (!stomp.isConnected && !stomp.isConnecting) {
      try {
        await stomp.connect(
          onError: (error) {
            debugPrint(
              '[MEDIA-STOMP] ERROR: $error',
            );
          },
        );
      } catch (e) {
        /*
     * 여기서 _subscribed를 false로 돌리지 않는다.
     *
     * logical subscription은 이미 StompService에
     * 저장되어 있으므로, 이후 reconnect 성공 시
     * 자동으로 실제 subscription이 복구된다.
     */
        debugPrint(
          '[MEDIA-STOMP] CONNECT ERROR: $e',
        );
      }
    }
  }

  void dispose() {
    _unsubscribe?.call(
      unsubscribeHeaders: {},
    );

    _unsubscribe = null;

    _subscribed = false;
  }
}
