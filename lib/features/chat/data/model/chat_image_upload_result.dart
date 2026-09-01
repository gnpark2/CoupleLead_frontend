class ChatImageUploadResult {
  final String url;

  const ChatImageUploadResult({
    required this.url,
  });

  factory ChatImageUploadResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatImageUploadResult(
      url: json['imageUrl'] as String,
    );
  }
}
