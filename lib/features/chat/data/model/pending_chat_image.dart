import 'dart:typed_data';

enum ChatImageUploadStatus {
  compressing,
  ready,
  uploading,
  completed,
  failed,
}

class PendingChatImage {
  final String name;

  final Uint8List originalBytes;

  final Uint8List? compressedBytes;

  final ChatImageUploadStatus status;

  /*
   * 같은 선택 묶음을 식별
   */
  final String? mediaGroupId;

  /*
   * 실제 IMAGE 채팅 메시지 식별
   */
  final String? clientMessageId;

  const PendingChatImage({
    required this.name,
    required this.originalBytes,
    this.compressedBytes,
    required this.status,
    this.mediaGroupId,
    this.clientMessageId,
  });

  PendingChatImage copyWith({
    String? name,
    Uint8List? originalBytes,
    Uint8List? compressedBytes,
    ChatImageUploadStatus? status,
    String? mediaGroupId,
    String? clientMessageId,
  }) {
    return PendingChatImage(
      name: name ?? this.name,
      originalBytes: originalBytes ?? this.originalBytes,
      compressedBytes: compressedBytes ?? this.compressedBytes,
      status: status ?? this.status,
      mediaGroupId: mediaGroupId ?? this.mediaGroupId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
    );
  }
}
