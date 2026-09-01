import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/domain/ChatMessageSendStatus.dart';
import '../data/model/chat_message.dart';
import 'chat_messages_state.dart';
import 'chat_provider.dart';

final chatMessagesControllerProvider = NotifierProvider.autoDispose
    .family<ChatMessagesController, ChatMessagesState, int>(
  ChatMessagesController.new,
);

class ChatMessagesController
    extends AutoDisposeFamilyNotifier<ChatMessagesState, int> {
  static const int _pageSize = 50;

  List<ChatMessage> _sortMessages(
    List<ChatMessage> messages,
  ) {
    final sorted = [
      ...messages,
    ];

    sorted.sort(
      (a, b) => a.sentAt.compareTo(
        b.sentAt,
      ),
    );

    return sorted;
  }

  @override
  ChatMessagesState build(
    int coupleId,
  ) {
    Future.microtask(
      loadInitial,
    );

    return const ChatMessagesState(
      loading: true,
    );
  }

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(
        loading: true,
        clearError: true,
      );

      final page = await ref.read(chatApiProvider).getMessages(
            arg,
            size: _pageSize,
          );

      final sortedMessages = _sortMessages(
        page.messages,
      );

      debugPrint(
        'INITIAL MESSAGE COUNT='
        '${sortedMessages.length}',
      );

      if (sortedMessages.isNotEmpty) {
        debugPrint(
          'INITIAL FIRST='
          '${sortedMessages.first.id} '
          '${sortedMessages.first.sentAt}',
        );

        debugPrint(
          'INITIAL LAST='
          '${sortedMessages.last.id} '
          '${sortedMessages.last.sentAt}',
        );
      }

      state = ChatMessagesState(
        messages: sortedMessages,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loading ||
        state.loadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(
      loadingMore: true,
      clearError: true,
    );

    try {
      final page = await ref.read(chatApiProvider).getMessages(
            arg,
            beforeMessageId: state.nextCursor,
            size: _pageSize,
          );

      /*
       * 과거 메시지는 현재 목록 앞에 붙인다.
       */
      final merged = _sortMessages([
        ...page.messages,
        ...state.messages,
      ]);

      state = state.copyWith(
        messages: merged,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        loadingMore: false,
        error: e,
      );
    }
  }

  void addTemporaryMessage(
    ChatMessage message,
  ) {
    state = state.copyWith(
      messages: _sortMessages([
        ...state.messages,
        message,
      ]),
    );
  }

  void markSendFailed(
    String clientMessageId,
  ) {
    final updated = state.messages.map(
      (message) {
        if (message.clientMessageId == clientMessageId &&
            message.id == null &&
            message.sendStatus == ChatMessageSendStatus.sending) {
          return message.copyWith(
            sendStatus: ChatMessageSendStatus.failed,
          );
        }

        return message;
      },
    ).toList();

    state = state.copyWith(
      messages: updated,
    );
  }

  void removePendingMessage(
    String clientMessageId,
  ) {
    state = state.copyWith(
      messages: state.messages
          .where(
            (message) => message.clientMessageId != clientMessageId,
          )
          .toList(),
    );
  }

  void addOrConfirmMessage(
    ChatMessage incoming,
  ) {
    final clientMessageId = incoming.clientMessageId;

    debugPrint(
      '[ADD OR CONFIRM] '
      'incoming.id=${incoming.id} '
      'clientMessageId=$clientMessageId',
    );

    if (clientMessageId != null) {
      final pendingIndex = state.messages.indexWhere(
        (message) =>
            message.clientMessageId == clientMessageId && message.id == null,
      );

      debugPrint(
        '[ADD OR CONFIRM] '
        'pendingIndex=$pendingIndex',
      );

      if (pendingIndex >= 0) {
        final updated = [
          ...state.messages,
        ];

        /*
       * 임시 메시지를 실제 서버 메시지로 교체
       */
        updated[pendingIndex] = incoming.copyWith(
          sendStatus: ChatMessageSendStatus.sent,
        );

        state = state.copyWith(
          messages: _sortMessages(updated),
          clearError: true,
        );

        return;
      }
    }

    /*
   * 이미 서버 메시지가 존재하는 경우
   * 중복 추가 방지
   */
    if (incoming.id != null) {
      final existingIndex = state.messages.indexWhere(
        (message) => message.id == incoming.id,
      );

      if (existingIndex >= 0) {
        final updated = [
          ...state.messages,
        ];

        updated[existingIndex] = incoming;

        state = state.copyWith(
          messages: _sortMessages(updated),
          clearError: true,
        );

        return;
      }
    }

    /*
   * 상대방의 완전히 새로운 메시지
   */
    state = state.copyWith(
      messages: _sortMessages([
        ...state.messages,
        incoming,
      ]),
      clearError: true,
    );
  }

  bool containsMessage(
    int messageId,
  ) {
    return state.messages.any(
      (message) => message.id == messageId,
    );
  }

  int indexOfMessage(
    int messageId,
  ) {
    return state.messages.indexWhere(
      (message) => message.id == messageId,
    );
  }

  /*
   * readAt 변경 후 전체 첫 페이지를
   * 다시 가져올 필요가 있을 때 사용.
   */
  Future<void> refreshLatest() async {
    try {
      final page = await ref.read(chatApiProvider).getMessages(
            arg,
            size: _pageSize,
          );

      /*
     * 서버에서 내려온 clientMessageId 목록.
     */
      final serverClientMessageIds = page.messages
          .map(
            (message) => message.clientMessageId,
          )
          .whereType<String>()
          .toSet();

      /*
     * 서버에 이미 확정된 pending 메시지는
     * 로컬에서 제거.
     *
     * 아직 서버에서 확인되지 않은
     * sending / failed 메시지만 유지.
     */
      final localPendingMessages = state.messages.where(
        (message) {
          if (message.id != null) {
            return false;
          }

          final clientMessageId = message.clientMessageId;

          if (clientMessageId == null) {
            return true;
          }

          return !serverClientMessageIds.contains(
            clientMessageId,
          );
        },
      ).toList();

      /*
     * 서버 messageId 기준 병합
     */
      final byId = <int, ChatMessage>{};

      for (final message in state.messages) {
        if (message.id != null) {
          byId[message.id!] = message;
        }
      }

      for (final message in page.messages) {
        if (message.id != null) {
          byId[message.id!] = message;
        }
      }

      final merged = _sortMessages([
        ...byId.values,
        ...localPendingMessages,
      ]);

      state = state.copyWith(
        messages: merged,
        clearError: true,
      );
    } catch (e) {
      debugPrint(
        'refreshLatest 실패: $e',
      );
    }
  }

  void markSending(
    String clientMessageId,
  ) {
    final updated = state.messages.map(
      (message) {
        if (message.id == null && message.clientMessageId == clientMessageId) {
          return message.copyWith(
            sendStatus: ChatMessageSendStatus.sending,
          );
        }

        return message;
      },
    ).toList();

    state = state.copyWith(
      messages: updated,
    );
  }
}
