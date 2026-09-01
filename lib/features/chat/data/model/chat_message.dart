import '../domain/ChatMessageSendStatus.dart';

class ChatMessage {
  final int? id;
  final int senderId;
  final String? senderNickname;
  final ChatMessageType type;
  final String content;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool deleted;
  final DateTime? deletedAt;
  final bool edited;
  final DateTime? editedAt;

  final String? clientMessageId;
  final ChatMessageSendStatus sendStatus;

  final int? replyToMessageId;
  final String? replyToSenderNickname;
  final ChatMessageType? replyToType;
  final String? replyToContent;

  final String? mediaGroupId;

  const ChatMessage(
      {this.id,
      required this.senderId,
      this.senderNickname,
      required this.type,
      required this.content,
      required this.sentAt,
      this.readAt,
      required this.deleted,
      required this.deletedAt,
      required this.edited,
      required this.editedAt,
      this.clientMessageId,
      this.sendStatus = ChatMessageSendStatus.sent,
      this.replyToMessageId,
      this.replyToSenderNickname,
      this.replyToType,
      this.replyToContent,
      this.mediaGroupId});

  factory ChatMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatMessage(
      id: (json['messageId'] as num?)?.toInt(),
      senderId: _requiredInt(
        json,
        'senderId',
      ),
      senderNickname: json['senderNickname'] as String?,
      type: switch (json['type']?.toString()) {
        'IMAGE' => ChatMessageType.image,
        _ => ChatMessageType.text,
      },
      content: json['content'] as String? ?? '',
      sentAt: _requiredDateTime(
        json,
        'sentAt',
      ),
      readAt: _nullableDateTime(
        json['readAt'],
      ),
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(
              json['deletedAt'] as String,
            )
          : null,
      edited: json['edited'] as bool? ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(
              json['editedAt'] as String,
            )
          : null,
      clientMessageId: json['clientMessageId'] as String?,
      sendStatus: ChatMessageSendStatus.sent,
      replyToMessageId: (json['replyToMessageId'] as num?)?.toInt(),
      replyToSenderNickname: json['replyToSenderNickname'] as String?,
      replyToType: switch (json['replyToType']?.toString()) {
        'TEXT' => ChatMessageType.text,
        'IMAGE' => ChatMessageType.image,
        _ => null,
      },
      replyToContent: json['replyToContent'] as String?,
      mediaGroupId: json['mediaGroupId'] as String?,
    );
  }

  static int _requiredInt(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is num) {
      return value.toInt();
    }

    throw FormatException(
      'ChatMessage.$key가 없거나 숫자가 아닙니다. '
      'value=$value, json=$json',
    );
  }

  static DateTime _requiredDateTime(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }

    throw FormatException(
      'ChatMessage.$key가 없거나 문자열이 아닙니다. '
      'value=$value, json=$json',
    );
  }

  static DateTime? _nullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }

    return null;
  }

  ChatMessage copyWith({
    int? id,
    int? senderId,
    String? senderNickname,
    ChatMessageType? type,
    String? content,
    DateTime? sentAt,
    DateTime? readAt,
    bool? deleted,
    DateTime? deletedAt,
    bool? edited,
    DateTime? editedAt,
    String? clientMessageId,
    ChatMessageSendStatus? sendStatus,
    int? replyToMessageId,
    String? replyToSenderNickname,
    ChatMessageType? replyToType,
    String? replyToContent,
    String? mediaGroupId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      type: type ?? this.type,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      edited: edited ?? this.edited,
      editedAt: editedAt ?? this.editedAt,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      sendStatus: sendStatus ?? this.sendStatus,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderNickname:
          replyToSenderNickname ?? this.replyToSenderNickname,
      replyToType: replyToType ?? this.replyToType,
      replyToContent: replyToContent ?? this.replyToContent,
      mediaGroupId: mediaGroupId ?? this.mediaGroupId,
    );
  }
}

enum ChatMessageType {
  text,
  image,
}
