import 'chat_message.dart';

class ChatHistoryPage {
  final List<ChatMessage> messages;
  final int? nextCursor;
  final bool hasMore;

  const ChatHistoryPage({
    required this.messages,
    required this.nextCursor,
    required this.hasMore
  });

  factory ChatHistoryPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];

    return ChatHistoryPage(
      messages: rawMessages
        .map(
          (item) => ChatMessage.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(),
        nextCursor:
          (json['nextCursor'] as num?)
            ?.toInt(),
        hasMore: 
          json['hasMore'] as bool? ?? false,
    );
  }
}