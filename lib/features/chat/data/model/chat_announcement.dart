class ChatAnnouncement {
  final int id;
  final int messageId;

  final int createdBy;
  final String createdByNickname;

  final int messageSenderId;
  final String messageSenderNickname;

  final String content;

  final DateTime messageSentAt;
  final DateTime createdAt;

  const ChatAnnouncement({
    required this.id,
    required this.messageId,
    required this.createdBy,
    required this.createdByNickname,
    required this.messageSenderId,
    required this.messageSenderNickname,
    required this.content,
    required this.messageSentAt,
    required this.createdAt,
  });

  factory ChatAnnouncement.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatAnnouncement(
      id: (json['id'] as num).toInt(),
      messageId: (json['messageId'] as num).toInt(),
      createdBy: (json['createdBy'] as num).toInt(),
      createdByNickname: json['createdByNickname'] as String? ?? '',
      messageSenderId: (json['messageSenderId'] as num).toInt(),
      messageSenderNickname: json['messageSenderNickname'] as String? ?? '',
      content: json['content'] as String? ?? '',
      messageSentAt: DateTime.parse(
        json['messageSentAt'] as String,
      ),
      createdAt: DateTime.parse(
        json['createdAt'] as String,
      ),
    );
  }
}
