import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage_native.dart';

typedef StompJsonCallback = void Function(
  Map<String, dynamic> data,
);

class StompService {
  final TokenStorage tokenStorage;

  StompService({
    required this.tokenStorage,
  });

  StompClient? _client;

  Completer<void>? _connectCompleter;

  Timer? _reconnectTimer;

  /*
   * 논리적인 subscription 목록.
   *
   * WebSocket이 끊겨도 유지된다.
   */
  final Map<String, _StompSubscription> _subscriptions = {};

  /*
   * 현재 실제 connection에 붙어 있는
   * unsubscribe callback.
   *
   * reconnect마다 새로 만들어진다.
   */
  final Map<String, StompUnsubscribe> _activeSubscriptions = {};

  int _subscriptionSequence = 0;

  bool _manualDisconnect = false;

  bool get isConnected =>
      _client?.connected ?? false;

  bool get isConnecting =>
      _connectCompleter != null &&
      !_connectCompleter!.isCompleted;

  Future<void> connect({
    void Function(Object error)? onError,
  }) async {
    /*
     * 이미 연결되어 있으면 아무것도 하지 않는다.
     */
    if (isConnected) {
      return;
    }

    /*
     * 현재 연결 중이면 같은 Future를 기다린다.
     */
    if (isConnecting) {
      return _connectCompleter!.future;
    }

    _manualDisconnect = false;

    /*
     * 기존 reconnect 예약이 있다면 제거.
     */
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    /*
     * 중요:
     * connect할 때마다 TokenStorage에서
     * 현재 access token을 다시 읽는다.
     */
    final accessToken =
        await tokenStorage.getAccessToken();

    if (accessToken == null ||
        accessToken.isEmpty) {
      throw StateError(
        'STOMP access token이 없습니다.',
      );
    }

    _connectCompleter =
        Completer<void>();

    _createClient(
      accessToken: accessToken,
      onError: onError,
    );

    _client!.activate();

    return _connectCompleter!.future;
  }

  void _createClient({
    required String accessToken,
    void Function(Object error)? onError,
  }) {
    debugPrint(
      '[STOMP] CREATE CLIENT '
      'tokenPresent=${accessToken.isNotEmpty}',
    );

    _client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,

        stompConnectHeaders: {
          'Authorization':
              'Bearer $accessToken',
        },

        onConnect: (frame) {
          debugPrint(
            '[STOMP] CONNECTED',
          );

          /*
           * reconnect 이후에도
           * 기존 논리 subscription 복구.
           */
          _restoreSubscriptions();

          if (!(_connectCompleter
                  ?.isCompleted ??
              true)) {
            _connectCompleter!
                .complete();
          }
        },

        onStompError: (frame) {
          final error =
              frame.body ??
              'STOMP ERROR';

          debugPrint(
            '[STOMP] ERROR: $error',
          );

          onError?.call(
            error,
          );
        },

        onWebSocketError: (error) {
          debugPrint(
            '[STOMP] WEBSOCKET ERROR: '
            '$error',
          );

          onError?.call(
            error,
          );

          if (!(_connectCompleter
                  ?.isCompleted ??
              true)) {
            _connectCompleter!
                .completeError(
              error,
            );
          }
        },

        onWebSocketDone: () {
          debugPrint(
            '[STOMP] WEBSOCKET DONE',
          );

          /*
           * 끊어진 connection의 unsubscribe는
           * 더 이상 유효하지 않다.
           */
          _activeSubscriptions
              .clear();

          /*
           * 현재 client는 더 이상 사용하지 않는다.
           */
          _client = null;

          /*
           * 연결 중 Future가 아직 남아있다면 정리.
           */
          if (!(_connectCompleter
                  ?.isCompleted ??
              true)) {
            _connectCompleter!
                .completeError(
              StateError(
                'STOMP connection closed.',
              ),
            );
          }

          _connectCompleter = null;

          if (!_manualDisconnect) {
            _scheduleReconnect(
              onError: onError,
            );
          }
        },

        /*
         * 매우 중요:
         *
         * stomp_dart_client 자체 reconnect를 끈다.
         *
         * 기존 StompClient를 자동 재사용하면
         * 오래된 Authorization header가
         * 계속 사용될 수 있다.
         */
        reconnectDelay:
            Duration.zero,

        heartbeatIncoming:
            const Duration(
          seconds: 10,
        ),

        heartbeatOutgoing:
            const Duration(
          seconds: 10,
        ),
      ),
    );
  }

  void _scheduleReconnect({
    void Function(Object error)? onError,
  }) {
    if (_manualDisconnect) {
      return;
    }

    /*
     * 여러 WebSocket callback이 동시에 발생해도
     * reconnect Timer는 하나만 존재하게 한다.
     */
    if (_reconnectTimer?.isActive ??
        false) {
      return;
    }

    debugPrint(
      '[STOMP] reconnect 대기 중...',
    );

    _reconnectTimer =
        Timer(
      const Duration(
        seconds: 5,
      ),
      () async {
        _reconnectTimer = null;

        if (_manualDisconnect) {
          return;
        }

        try {
          debugPrint(
            '[STOMP] reconnect 시도',
          );

          /*
           * 여기서 다시 connect()한다.
           *
           * 따라서 TokenStorage에서
           * 최신 access token을 다시 읽는다.
           */
          await connect(
            onError: onError,
          );
        } catch (e) {
          debugPrint(
            '[STOMP] reconnect 실패: $e',
          );

          onError?.call(
            e,
          );

          /*
           * 실패했다면 다시 5초 후 시도.
           */
          _scheduleReconnect(
            onError: onError,
          );
        }
      },
    );
  }

  StompUnsubscribe? subscribe({
    required String destination,
    required StompJsonCallback onMessage,
  }) {
    final subscriptionId =
        'sub-${_subscriptionSequence++}';

    final subscription =
        _StompSubscription(
      id: subscriptionId,
      destination:
          destination,
      onMessage:
          onMessage,
    );

    /*
     * 논리적인 subscription 저장.
     */
    _subscriptions[
        subscriptionId] = subscription;

    /*
     * 현재 STOMP가 살아있으면 즉시 subscribe.
     *
     * 연결 전이라면 onConnect 시
     * _restoreSubscriptions()에서 붙는다.
     */
    if (isConnected) {
      _activateSubscription(
        subscription,
      );
    }

    return ({
      Map<String, String>?
          unsubscribeHeaders,
    }) {
      _removeSubscription(
        subscriptionId,
        unsubscribeHeaders:
            unsubscribeHeaders,
      );
    };
  }

  void _activateSubscription(
    _StompSubscription subscription,
  ) {
    final client =
        _client;

    if (client == null ||
        !client.connected) {
      return;
    }

    /*
     * 동일 connection에서
     * 중복 subscribe 방지.
     */
    if (_activeSubscriptions
        .containsKey(
      subscription.id,
    )) {
      return;
    }

    debugPrint(
      '[STOMP] SUBSCRIBE '
      '${subscription.destination}',
    );

    final unsubscribe =
        client.subscribe(
      destination:
          subscription.destination,

      callback:
          (frame) {
        final body =
            frame.body;

        if (body == null ||
            body.isEmpty) {
          return;
        }

        try {
          final decoded =
              jsonDecode(
            body,
          );

          if (decoded
              is Map<String,
                  dynamic>) {
            subscription
                .onMessage(
              decoded,
            );

            return;
          }

          if (decoded is Map) {
            subscription
                .onMessage(
              Map<String,
                      dynamic>.from(
                decoded,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            '[STOMP] JSON parse error: '
            '$e',
          );
        }
      },
    );

    _activeSubscriptions[
            subscription.id] =
        unsubscribe;
  }

  void _restoreSubscriptions() {
    /*
     * 이전 WebSocket에서 사용한 unsubscribe는
     * 새 connection에서 의미가 없다.
     */
    _activeSubscriptions
        .clear();

    debugPrint(
      '[STOMP] RESTORE SUBSCRIPTIONS '
      'count=${_subscriptions.length}',
    );

    for (final subscription
        in _subscriptions.values) {
      _activateSubscription(
        subscription,
      );
    }
  }

  void _removeSubscription(
    String subscriptionId, {
    Map<String, String>?
        unsubscribeHeaders,
  }) {
    /*
     * logical registry에서도 제거해야
     * reconnect 이후 다시 붙지 않는다.
     */
    _subscriptions.remove(
      subscriptionId,
    );

    final active =
        _activeSubscriptions.remove(
      subscriptionId,
    );

    if (active == null) {
      return;
    }

    try {
      active(
        unsubscribeHeaders:
            unsubscribeHeaders ??
                {},
      );
    } catch (e) {
      debugPrint(
        '[STOMP] UNSUBSCRIBE ERROR: '
        '$e',
      );
    }
  }

  void send({
    required String destination,
    required Map<String, dynamic>
        body,
  }) {
    final client =
        _client;

    if (client == null ||
        !client.connected) {
      debugPrint(
        '[STOMP] SEND SKIPPED: '
        'not connected',
      );

      return;
    }

    client.send(
      destination:
          destination,
      body:
          jsonEncode(
        body,
      ),
    );
  }

  void disconnect() {
    debugPrint(
      '[STOMP] MANUAL DISCONNECT',
    );

    _manualDisconnect =
        true;

    /*
     * 예약되어 있던 reconnect 취소.
     */
    _reconnectTimer?.cancel();
    _reconnectTimer =
        null;

    /*
     * 로그아웃 등 완전 종료에서는
     * logical subscription도 제거.
     */
    _subscriptions.clear();
    _activeSubscriptions.clear();

    if (!(_connectCompleter
            ?.isCompleted ??
        true)) {
      _connectCompleter!
          .completeError(
        StateError(
          'STOMP connection cancelled.',
        ),
      );
    }

    _client?.deactivate();

    _client =
        null;

    _connectCompleter =
        null;
  }
}

class _StompSubscription {
  final String id;

  final String destination;

  final StompJsonCallback
      onMessage;

  const _StompSubscription({
    required this.id,
    required this.destination,
    required this.onMessage,
  });
}