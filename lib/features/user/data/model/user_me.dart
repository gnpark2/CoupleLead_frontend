class UserMe {
  final int id;
  final String email;
  final String nickname;
  final String? profileImage;
  final String? country;
  final String? city;
  final String? timezone;
  final double? latitude;
  final double? longitude;

  const UserMe({
    required this.id,
    required this.email,
    required this.nickname,
    this.profileImage,
    this.country,
    this.city,
    this.timezone,
    this.latitude,
    this.longitude,
  });

  factory UserMe.fromJson(
    Map<String, dynamic> json,
  ) {
    return UserMe(
      id: json['id'] as int,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      profileImage:
          json['profileImage'] as String?,
      country:
          json['country'] as String?,
      city:
          json['city'] as String?,
      timezone:
          json['timezone'] as String?,
      latitude:
          (json['latitude'] as num?)
              ?.toDouble(),
      longitude:
          (json['longitude'] as num?)
              ?.toDouble(),
    );
  }
}