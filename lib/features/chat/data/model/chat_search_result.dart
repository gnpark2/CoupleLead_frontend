class ChatSearchResult {
  final int messageId;
  final int senderId;
  final String senderNickname;
  final String content;
  final DateTime sentAt;

  const ChatSearchResult({
    required this.messageId,
    required this.senderId,
    required this.senderNickname,
    required this.content,
    required this.sentAt,
  });

  factory ChatSearchResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatSearchResult(
      messageId: (json['messageId'] as num).toInt(),
      senderId: (json['senderId'] as num).toInt(),
      senderNickname: json['senderNickname'] as String? ?? '',
      content: json['content'] as String? ?? '',
      sentAt: DateTime.parse(
        json['sentAt'] as String,
      ),
    );
  }
}
