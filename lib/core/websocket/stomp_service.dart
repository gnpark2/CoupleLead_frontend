import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../constants/api_constants.dart';

typedef StompJsonCallback = void Function(
  Map<String, dynamic> data,
);

class StompService {
  StompClient? _client;

  String? _accessToken;

  Completer<void>? _connectCompleter;

  /*
   * 우리가 원하는 논리적인 subscription 목록.
   *
   * WebSocket이 끊겨도 이 목록은 유지한다.
   */
  final Map<String, _StompSubscription> _subscriptions = {};

  /*
   * 현재 실제 STOMP connection에 붙어 있는
   * unsubscribe callback.
   *
   * reconnect 시 새롭게 만들어진다.
   */
  final Map<String, StompUnsubscribe> _activeSubscriptions = {};

  int _subscriptionSequence = 0;

  bool _manualDisconnect = false;

  bool get isConnected => _client?.connected ?? false;

  bool get isConnecting =>
      _connectCompleter != null && !_connectCompleter!.isCompleted;

  Future<void> connect({
    required String accessToken,
    void Function(Object error)? onError,
  }) async {
    _accessToken = accessToken;

    if (isConnected) {
      return;
    }

    if (isConnecting) {
      return _connectCompleter!.future;
    }

    _manualDisconnect = false;
    _connectCompleter = Completer<void>();
    _createClient(
      onError: onError,
    );

    _client!.activate();

    return _connectCompleter!.future;
  }

  void _createClient({
    void Function(Object error)? onError,
  }) {
    final token = _accessToken;

    if (token == null || token.isEmpty) {
      throw StateError(
        'STOMP access token이 없습니다.',
      );
    }

    debugPrint(
      'STOMP CREATE CLIENT '
      'tokenPresent=${token.isNotEmpty}',
    );

    _client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onConnect: (frame) {
          debugPrint(
            'STOMP CONNECTED',
          );

          _restoreSubscriptions();

          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter!.complete();
          }
        },
        onStompError: (frame) {
          final error = frame.body ?? 'STOMP ERROR';

          debugPrint(
            'STOMP ERROR: $error',
          );

          onError?.call(
            error,
          );
        },
        onWebSocketError: (error) {
          debugPrint(
            'STOMP WEBSOCKET ERROR: '
            '$error',
          );

          onError?.call(
            error,
          );

          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter!.completeError(
              error,
            );
          }
        },
        onWebSocketDone: () {
          debugPrint(
            'STOMP WEBSOCKET DONE',
          );

          _activeSubscriptions.clear();

          if (!_manualDisconnect) {
            debugPrint(
              'STOMP reconnect '
              '대기 중...',
            );
          }
        },
        reconnectDelay: const Duration(
          seconds: 5,
        ),
        heartbeatIncoming: const Duration(
          seconds: 10,
        ),
        heartbeatOutgoing: const Duration(
          seconds: 10,
        ),
      ),
    );
  }

  /*
   * 기존 Controller들이 사용하는 subscribe API.
   *
   * 이제 실제 StompUnsubscribe를 그대로 반환하지 않고,
   * Service가 만든 unsubscribe 함수를 반환한다.
   */
  StompUnsubscribe? subscribe({
    required String destination,
    required StompJsonCallback onMessage,
  }) {
    /*
     * destination이 같더라도
     * Home / Chat에서 각각 구독할 수 있으므로
     * 고유 ID를 만든다.
     */
    final subscriptionId = 'sub-${_subscriptionSequence++}';

    final subscription = _StompSubscription(
      id: subscriptionId,
      destination: destination,
      onMessage: onMessage,
    );

    /*
     * 논리적 구독 등록
     */
    _subscriptions[subscriptionId] = subscription;

    /*
     * 현재 연결돼 있다면 즉시 실제 subscribe.
     *
     * 아직 연결 전이면 registry만 저장하고
     * onConnect 시 자동 subscribe.
     */
    if (isConnected) {
      _activateSubscription(
        subscription,
      );
    }

    /*
     * Controller에서는 기존과 똑같이
     *
     * unsubscribe(
     *   unsubscribeHeaders: {},
     * );
     *
     * 로 사용할 수 있다.
     */
    return ({
      Map<String, String>? unsubscribeHeaders,
    }) {
      _removeSubscription(
        subscriptionId,
        unsubscribeHeaders: unsubscribeHeaders,
      );
    };
  }

  void _activateSubscription(
    _StompSubscription subscription,
  ) {
    final client = _client;

    if (client == null || !client.connected) {
      return;
    }

    /*
     * 같은 logical subscription이
     * 현재 connection에 이미 있으면 중복 방지.
     */
    if (_activeSubscriptions.containsKey(
      subscription.id,
    )) {
      return;
    }

    debugPrint(
      'STOMP SUBSCRIBE '
      '${subscription.destination}',
    );

    final unsubscribe = client.subscribe(
      destination: subscription.destination,
      callback: (frame) {
        final body = frame.body;

        if (body == null || body.isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(body);

          if (decoded is Map<String, dynamic>) {
            subscription.onMessage(
              decoded,
            );

            return;
          }

          /*
           * jsonDecode 결과가 Map<dynamic,dynamic>
           * 형태로 잡히는 경우까지 안전하게 처리
           */
          if (decoded is Map) {
            subscription.onMessage(
              Map<String, dynamic>.from(
                decoded,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            'STOMP JSON parse error: '
            '$e',
          );
        }
      },
    );

    _activeSubscriptions[subscription.id] = unsubscribe;
  }

  /*
   * 최초 connect와 reconnect 모두
   * onConnect에서 실행된다.
   */
  void _restoreSubscriptions() {
    /*
     * 이전 connection의 unsubscribe는
     * 새 connection에서는 의미가 없다.
     */
    _activeSubscriptions.clear();

    debugPrint(
      'STOMP RESTORE SUBSCRIPTIONS '
      'count=${_subscriptions.length}',
    );

    for (final subscription in _subscriptions.values) {
      _activateSubscription(
        subscription,
      );
    }
  }

  void _removeSubscription(
    String subscriptionId, {
    Map<String, String>? unsubscribeHeaders,
  }) {
    /*
     * reconnect 때 다시 붙지 않도록
     * registry에서 먼저 삭제.
     */
    _subscriptions.remove(
      subscriptionId,
    );

    final active = _activeSubscriptions.remove(
      subscriptionId,
    );

    if (active == null) {
      return;
    }

    try {
      active(
        unsubscribeHeaders: unsubscribeHeaders ?? {},
      );
    } catch (e) {
      /*
       * socket이 이미 끊어진 상태에서
       * dispose될 수도 있으므로 앱까지 실패시키지 않는다.
       */
      debugPrint(
        'STOMP UNSUBSCRIBE ERROR: '
        '$e',
      );
    }
  }

  void send({
    required String destination,
    required Map<String, dynamic> body,
  }) {
    final client = _client;

    if (client == null || !client.connected) {
      debugPrint(
        'STOMP SEND SKIPPED: '
        'not connected',
      );

      return;
    }

    client.send(
      destination: destination,
      body: jsonEncode(
        body,
      ),
    );
  }

  void disconnect() {
    debugPrint(
      'STOMP MANUAL DISCONNECT',
    );

    _manualDisconnect = true;

    _subscriptions.clear();
    _activeSubscriptions.clear();

    _accessToken = null;

    if (!(_connectCompleter?.isCompleted ?? true)) {
      _connectCompleter!.completeError(
        StateError(
          'STOMP connection cancelled.',
        ),
      );
    }

    _client?.deactivate();

    _client = null;
    _connectCompleter = null;
  }
}

class _StompSubscription {
  final String id;

  final String destination;

  final StompJsonCallback onMessage;

  const _StompSubscription({
    required this.id,
    required this.destination,
    required this.onMessage,
  });
}
