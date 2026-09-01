class LoginResponse {
  final String accessToken;
  final String? refreshToken;

  const LoginResponse({
    required this.accessToken,
    this.refreshToken,
  });

  factory LoginResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return LoginResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}
