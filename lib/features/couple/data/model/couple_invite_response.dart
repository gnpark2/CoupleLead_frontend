class CoupleInviteResponse {
  final String inviteCode;

  const CoupleInviteResponse({
    required this.inviteCode,
  });

  factory CoupleInviteResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return CoupleInviteResponse(
      inviteCode: json['inviteCode'] as String,
    );
  }
}
