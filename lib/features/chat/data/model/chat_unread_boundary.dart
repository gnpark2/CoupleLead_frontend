class ChatUnreadBoundary {
  final int? firstUnreadMessageId;
  final int unreadCount;

  const ChatUnreadBoundary({
    required this.firstUnreadMessageId,
    required this.unreadCount,
  });

  factory ChatUnreadBoundary.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatUnreadBoundary(
      firstUnreadMessageId: (json['firstUnreadMessageId'] as num?)?.toInt(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
