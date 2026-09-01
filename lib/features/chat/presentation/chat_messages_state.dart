import '../data/model/chat_message.dart';

class ChatMessagesState {
  final List<ChatMessage> messages;

  final int? nextCursor;

  final bool hasMore;

  final bool loading;

  final bool loadingMore;

  final Object? error;

  const ChatMessagesState({
    this.messages = const [],
    this.nextCursor,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  ChatMessagesState copyWith({
    List<ChatMessage>? messages,
    int? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : error ?? this.error,
    );
  }
}
