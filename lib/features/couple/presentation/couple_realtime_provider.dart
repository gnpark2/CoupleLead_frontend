import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/websocket/stomp_provider.dart';
import '../../auth/presentation/auth_provider.dart';

final coupleRealtimeProvider = Provider.family<CoupleRealtimeController, int>(
  (
    ref,
    userId,
  ) {
    final controller = CoupleRealtimeController(
      ref: ref,
      userId: userId,
    );

    ref.onDispose(
      controller.dispose,
    );

    return controller;
  },
);

class CoupleRealtimeController {
  final Ref ref;
  final int userId;

  CoupleRealtimeController({
    required this.ref,
    required this.userId,
  });

  StompUnsubscribe? _unsubscribe;

  bool _subscribed = false;

  Future<void> start({
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) async {
    if (_subscribed) {
      return;
    }

    final stomp = ref.read(
      stompServiceProvider,
    );

    /*
     * 아직 STOMP 연결 전이면 연결
     */
    if (!stomp.isConnected) {
      try {
        await stomp.connect(
          onError: (error) {
            // 필요하면 debugPrint 추가
          },
        );
      } catch (e) {
        return;
      }
    }

    if (!stomp.isConnected) {
      return;
    }

    _unsubscribe = stomp.subscribe(
      destination: ApiConstants.coupleUserTopic(
        userId,
      ),
      onMessage: (data) {
        final type = data['type'];

        if (type == 'COUPLE_CONNECTED') {
          onConnected();

          return;
        }

        if (type == 'COUPLE_DISCONNECTED') {
          onDisconnected();

          return;
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

    /*
   * stomp.disconnect()는 호출하지 않음.
   *
   * STOMP 연결은 다른 실시간 기능에서도
   * 공유해서 사용하기 때문.
   */
  }
}
