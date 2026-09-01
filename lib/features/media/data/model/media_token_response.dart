class MediaTokenResponse {
  final String url;

  final String token;

  final String roomName;

  const MediaTokenResponse({
    required this.url,
    required this.token,
    required this.roomName,
  });

  factory MediaTokenResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return MediaTokenResponse(
      url: json['url'] as String,
      token: json['token'] as String,
      roomName: json['roomName'] as String,
    );
  }
}
