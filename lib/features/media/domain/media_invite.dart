class MediaInvite {
  final String callId;

  final int callerUserId;

  final String callerNickname;

  const MediaInvite({
    required this.callId,
    required this.callerUserId,
    required this.callerNickname,
  });

  factory MediaInvite.fromJson(
    Map<String, dynamic> json,
  ) {
    return MediaInvite(
      callId: json['callId'] as String,
      callerUserId: json['callerUserId'] as int,
      callerNickname: json['callerNickname'] as String,
    );
  }
}
