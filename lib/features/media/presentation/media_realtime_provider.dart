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

    if (!stomp.isConnected) {
      final token = await ref
          .read(
            tokenStorageProvider,
          )
          .getAccessToken();

      if (token == null) {
        return;
      }

      await stomp.connect(
        accessToken: token,
        onError: (error) {},
      );
    }

    if (!stomp.isConnected) {
      return;
    }

    _unsubscribe = stomp.subscribe(
      destination: ApiConstants.mediaUserTopic(
        userId,
      ),
      onMessage: (data) {
        final type = data['type'] as String?;

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
            onMediaLeft!(
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
  }

  void dispose() {
    _unsubscribe?.call(
      unsubscribeHeaders: {},
    );

    _unsubscribe = null;

    _subscribed = false;
  }

  void Function(
    Map<String, dynamic> data,
  )? onMediaLeft;
}
