import 'chat_search_result.dart';

class ChatSearchPage {
  final List<ChatSearchResult> messages;
  final DateTime? nextSentAt;
  final int? nextMessageId;
  final bool hasMore;

  const ChatSearchPage({
    required this.messages,
    required this.nextSentAt,
    required this.nextMessageId,
    required this.hasMore,
  });

  factory ChatSearchPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final messages = json['messages'] as List<dynamic>? ?? [];

    return ChatSearchPage(
      messages: messages
          .map(
            (item) => ChatSearchResult.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      nextSentAt: json['nextSentAt'] == null
          ? null
          : DateTime.parse(
              json['nextSentAt'] as String,
            ),
      nextMessageId: json['nextMessageId'] == null
          ? null
          : (json['nextMessageId'] as num).toInt(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
