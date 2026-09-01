import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/websocket/stomp_provider.dart';
import '../../../core/websocket/stomp_service.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../widget/presentation/widget_provider.dart';
import '../data/domain/ChatMessageSendStatus.dart';
import '../data/model/chat_message.dart';
import 'chat_announcement_provider.dart';
import 'chat_provider.dart';
import 'chat_realtime_state.dart';
import 'chat_messages_controller.dart';

class ChatRealtimeArgs {
  final int coupleId;
  final int myUserId;
  final int partnerId;

  const ChatRealtimeArgs({
    required this.coupleId,
    required this.myUserId,
    required this.partnerId,
  });

  @override
  bool operator ==(
    Object other,
  ) {
    return other is ChatRealtimeArgs &&
        other.coupleId == coupleId &&
        other.myUserId == myUserId &&
        other.partnerId == partnerId;
  }

  @override
  int get hashCode => Object.hash(
        coupleId,
        myUserId,
        partnerId,
      );
}

final chatRealtimeProvider = NotifierProvider.autoDispose
    .family<ChatRealtimeController, ChatRealtimeState, ChatRealtimeArgs>(
  ChatRealtimeController.new,
);

class ChatRealtimeController
    extends AutoDisposeFamilyNotifier<ChatRealtimeState, ChatRealtimeArgs> {
  Timer? _typingTimer;
  Timer? _typingSendTimer;

  final Map<String, Timer> _sendTimeoutTimers = {};

  bool _subscribed = false;

  final List<StompUnsubscribe> _subscriptions = [];

  final Uuid _uuid = const Uuid();

  final Set<String> _retryingClientMessageIds = {};

  StompService get _stomp => ref.read(stompServiceProvider);

  @override
  ChatRealtimeState build(
    ChatRealtimeArgs arg,
  ) {
    ref.onDispose(() {
      _typingTimer?.cancel();
      _typingSendTimer?.cancel();

      for (final unsubscribe in _subscriptions) {
        unsubscribe(
          unsubscribeHeaders: {},
        );
      }

      _subscriptions.clear();

      _subscribed = false;

      /*
     * 전송 timeout 정리
     */
      for (final timer in _sendTimeoutTimers.values) {
        timer.cancel();
      }

      _sendTimeoutTimers.clear();

      _retryingClientMessageIds.clear();
    });

    _connect();

    return const ChatRealtimeState();
  }

  Future<void> _connect() async {
    final tokenStorage = ref.read(tokenStorageProvider);

    final accessToken = await tokenStorage.getAccessToken();

    if (accessToken == null) {
      return;
    }

    final stomp = ref.read(stompServiceProvider);

    try {
      await stomp.connect(
        accessToken: accessToken,
        onError: (error) {
          print(
            'STOMP ERROR: $error',
          );
        },
      );

      state = state.copyWith(
        connected: true,
      );

      _subscribe();
    } catch (e) {
      print(
        'STOMP CONNECT ERROR: $e',
      );
    }
  }

  void _subscribe() {
    if (_subscribed) {
      return;
    }

    final stomp = ref.read(
      stompServiceProvider,
    );

    if (!stomp.isConnected) {
      return;
    }

    _subscribed = true;

    final chatSubscription = stomp.subscribe(
      destination: ApiConstants.chatTopic(
        arg.coupleId,
      ),
      onMessage: (data) async {
        final senderId = (data['senderId'] as num?)?.toInt();

        final type = data['type']?.toString();

        final content =
            type == 'IMAGE' ? '사진을 보냈습니다.' : data['content']?.toString();

        /*
     * 디버깅용:
     * clientMessageId가 서버를 거쳐
     * 정상적으로 돌아오는지 확인.
     */
        debugPrint(
          '[CHAT RECEIVE] '
          'messageId=${data['messageId']} '
          'clientMessageId='
          '${data['clientMessageId']}',
        );

        final incomingMessage = ChatMessage.fromJson(
          Map<String, dynamic>.from(
            data,
          ),
        );

        final clientMessageId = incomingMessage.clientMessageId;

//
//        임시  다중 이미지 전송 실패 테스트
//
//         if (incomingMessage.senderId == arg.myUserId &&
//             incomingMessage.type == ChatMessageType.image) {
//           debugPrint(
//             '[TEST] IMAGE confirmation ignored',
//           );

//           return;
//         }

        if (clientMessageId != null) {
          _sendTimeoutTimers.remove(clientMessageId)?.cancel();

          _retryingClientMessageIds.remove(
            clientMessageId,
          );
        }

        final messagesController = ref.read(
          chatMessagesControllerProvider(
            arg.coupleId,
          ).notifier,
        );

        /*
     * 내가 보낸 메시지:
     * pending → sent
     *
     * 상대방 메시지:
     * 새로운 메시지로 추가
     */
        messagesController.addOrConfirmMessage(
          incomingMessage,
        );

        ref.invalidate(
          coupleWidgetProvider,
        );

        /*
     * 상대방 메시지만 처리
     */
        if (senderId != null && senderId != arg.myUserId) {
          state = state.copyWith(
            incomingMessageVersion: state.incomingMessageVersion + 1,
            latestIncomingContent: content ?? '새 메시지가 도착했습니다.',
          );

          try {
            await ref
                .read(
                  chatApiProvider,
                )
                .markAsRead(
                  arg.coupleId,
                );

            /*
         * readAt 최신 상태 반영
         */
            await messagesController.refreshLatest();

            ref.invalidate(
              coupleWidgetProvider,
            );
          } catch (e) {
            debugPrint(
              '실시간 읽음 처리 실패: $e',
            );
          }
        }
      },
    );

    if (chatSubscription != null) {
      _subscriptions.add(
        chatSubscription,
      );
    }

    final announcementSubscription = stomp.subscribe(
      destination: ApiConstants.chatAnnouncementTopic(
        arg.coupleId,
      ),
      onMessage: (_) {
        ref.invalidate(
          chatAnnouncementProvider(
            arg.coupleId,
          ),
        );
      },
    );

    if (announcementSubscription != null) {
      _subscriptions.add(
        announcementSubscription,
      );
    }

    final readSubscription = stomp.subscribe(
      destination: ApiConstants.chatReadTopic(
        arg.coupleId,
      ),
      onMessage: (_) async {
        /*
     * 상대방이 읽었다면
     * 내 메시지의 readAt 값을 최신 상태로 갱신
     */
        await ref
            .read(
              chatMessagesControllerProvider(
                arg.coupleId,
              ).notifier,
            )
            .refreshLatest();

        final refreshedWidget = await ref.refresh(
          coupleWidgetProvider.future,
        );

        debugPrint(
          'READ 이벤트 후 unreadCount='
          '${refreshedWidget.unreadCount}',
        );
      },
    );

    if (readSubscription != null) {
      _subscriptions.add(
        readSubscription,
      );
    }

    final typingSubscription = stomp.subscribe(
      destination: ApiConstants.chatTypingTopic(
        arg.coupleId,
      ),
      onMessage: (data) {
        final senderId = (data['userId'] as num?)?.toInt();

        /*
         * partner가 보낸 typing만 처리
         */
        if (senderId != arg.partnerId) {
          return;
        }

        state = state.copyWith(
          partnerTyping: true,
        );

        _typingTimer?.cancel();

        _typingTimer = Timer(
          const Duration(
            seconds: 2,
          ),
          () {
            state = state.copyWith(
              partnerTyping: false,
            );
          },
        );
      },
    );

    if (typingSubscription != null) {
      _subscriptions.add(
        typingSubscription,
      );
    }

    final editSubscription = _stomp.subscribe(
      destination: ApiConstants.chatEditTopic(
        arg.coupleId,
      ),
      onMessage: (
        data,
      ) async {
        debugPrint(
          'CHAT EDIT EVENT: $data',
        );

        await ref
            .read(
              chatMessagesControllerProvider(
                arg.coupleId,
              ).notifier,
            )
            .refreshLatest();

        ref.invalidate(
          coupleWidgetProvider,
        );
      },
    );

    if (editSubscription != null) {
      _subscriptions.add(
        editSubscription,
      );
    }

    final deleteSubscription = stomp.subscribe(
      destination: ApiConstants.chatDeleteTopic(
        arg.coupleId,
      ),
      onMessage: (data) async {
        debugPrint(
          'CHAT DELETE EVENT: $data',
        );

        /*
     * 삭제된 상태를 서버에서 다시 받아온다.
     */
        await ref
            .read(
              chatMessagesControllerProvider(
                arg.coupleId,
              ).notifier,
            )
            .refreshLatest();

        ref.invalidate(
          coupleWidgetProvider,
        );
      },
    );

    if (deleteSubscription != null) {
      _subscriptions.add(
        deleteSubscription,
      );
    }
  }

  void sendMessage(
    String content, {
    int? replyToMessageId,
  }) {
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      return;
    }

    _sendChatMessage(
      type: ChatMessageType.text,
      content: trimmed,
      replyToMessageId: replyToMessageId,
    );
  }

  void _sendChatMessage({
    required ChatMessageType type,
    required String content,
    int? replyToMessageId,
    String? mediaGroupId,
    String? clientMessageId,

    /*
   * retry에서는 기존 temporary message가 있기 때문에
   * false로 사용한다.
   */
    bool addTemporaryMessage = true,
  }) {
    final resolvedClientMessageId = clientMessageId ?? _uuid.v4();

    final messagesController = ref.read(
      chatMessagesControllerProvider(
        arg.coupleId,
      ).notifier,
    );

    /*
   * 신규 전송일 때만
   * optimistic message 추가
   */
    if (addTemporaryMessage) {
      final temporaryMessage = ChatMessage(
        id: null,
        senderId: arg.myUserId,
        senderNickname: null,
        type: type,
        content: content,
        sentAt: DateTime.now(),
        readAt: null,
        deleted: false,
        deletedAt: null,
        edited: false,
        editedAt: null,
        clientMessageId: resolvedClientMessageId,
        sendStatus: ChatMessageSendStatus.sending,
        replyToMessageId: replyToMessageId,
        replyToSenderNickname: null,
        replyToType: null,
        replyToContent: null,

        /*
       * 이미지 그룹
       */
        mediaGroupId: mediaGroupId,
      );

      messagesController.addTemporaryMessage(
        temporaryMessage,
      );
    }

    // 개별 실패 리로드 테스트 코드
    // if (type == ChatMessageType.image && addTemporaryMessage) {
    //   debugPrint(
    //     '[TEST] Force IMAGE send failed: '
    //     '$resolvedClientMessageId',
    //   );

    //   messagesController.markSendFailed(
    //     resolvedClientMessageId,
    //   );

    //   return;
    // }

    /*
   * STOMP 연결이 끊겨 있으면
   * 즉시 failed 처리
   */
    if (!_stomp.isConnected) {
      _retryingClientMessageIds.remove(
        resolvedClientMessageId,
      );

      messagesController.markSendFailed(
        resolvedClientMessageId,
      );

      return;
    }

    try {
      /*
     * 혹시 기존 timeout이 남아 있으면 제거
     */
      _sendTimeoutTimers
          .remove(
            resolvedClientMessageId,
          )
          ?.cancel();

      _stomp.send(
        destination: ApiConstants.chatSend,
        body: {
          'coupleId': arg.coupleId,
          'type': type == ChatMessageType.image ? 'IMAGE' : 'TEXT',
          'content': content,
          'replyToMessageId': replyToMessageId,

          /*
         * TEXT에서는 null,
         * IMAGE 그룹이면 UUID
         */
          'mediaGroupId': mediaGroupId,

          /*
         * TEXT / IMAGE 모두 사용
         */
          'clientMessageId': resolvedClientMessageId,
        },
      );

      /*
     * 서버 확정 응답이 8초 내 오지 않으면
     * failed 처리
     */
      _sendTimeoutTimers[resolvedClientMessageId] = Timer(
        const Duration(
          seconds: 8,
        ),
        () {
          _sendTimeoutTimers.remove(
            resolvedClientMessageId,
          );

          _retryingClientMessageIds.remove(
            resolvedClientMessageId,
          );

          messagesController.markSendFailed(
            resolvedClientMessageId,
          );
        },
      );
    } catch (e) {
      _sendTimeoutTimers
          .remove(
            resolvedClientMessageId,
          )
          ?.cancel();

      _retryingClientMessageIds.remove(
        resolvedClientMessageId,
      );

      messagesController.markSendFailed(
        resolvedClientMessageId,
      );

      debugPrint(
        'CHAT SEND FAILED: $e',
      );
    }
  }

  void sendTyping() {
    if (_typingSendTimer?.isActive ?? false) {
      return;
    }

    if (!_stomp.isConnected) {
      return;
    }

    _stomp.send(
      destination: ApiConstants.chatTyping,
      body: {
        'coupleId': arg.coupleId,
      },
    );

    _typingSendTimer = Timer(
      const Duration(
        milliseconds: 800,
      ),
      () {},
    );
  }

  void sendImage(
    String imageUrl, {
    int? replyToMessageId,
    String? mediaGroupId,
    String? clientMessageId,
  }) {
    if (imageUrl.trim().isEmpty) {
      return;
    }

    _sendChatMessage(
      type: ChatMessageType.image,
      content: imageUrl,
      replyToMessageId: replyToMessageId,
      mediaGroupId: mediaGroupId,
      clientMessageId: clientMessageId,
    );
  }

  void retryMessage(
    ChatMessage message,
  ) {
    final clientMessageId = message.clientMessageId;

    if (clientMessageId == null || clientMessageId.isEmpty) {
      return;
    }

    /*
   * 이미 재전송 중이라면
   * 중복 클릭 차단
   */
    if (_retryingClientMessageIds.contains(
      clientMessageId,
    )) {
      return;
    }

    final messagesController = ref.read(
      chatMessagesControllerProvider(
        arg.coupleId,
      ).notifier,
    );

    /*
   * retry 시작
   */
    _retryingClientMessageIds.add(
      clientMessageId,
    );

    /*
   * failed → sending
   */
    messagesController.markSending(
      clientMessageId,
    );

    /*
   * 중요:
   *
   * 새로운 optimistic message를
   * 추가하지 않는다.
   *
   * 기존 failed message를 그대로
   * sending 상태로 재사용한다.
   */
    _sendChatMessage(
      type: message.type,
      content: message.content,
      replyToMessageId: message.replyToMessageId,
      mediaGroupId: message.mediaGroupId,

      /*
     * 반드시 기존 UUID 재사용
     */
      clientMessageId: clientMessageId,

      /*
     * 기존 temporary message가 있으므로
     * 새로 추가하지 않는다.
     */
      addTemporaryMessage: false,
    );
  }
}
