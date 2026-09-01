class WidgetPerson {
  final int id;
  final String nickname;

  final String? city;
  final String? timezone;
  final String? localTime;

  final double? temperature;
  final String? weatherCondition;
  final String? weatherIcon;

  const WidgetPerson({
    required this.id,
    required this.nickname,
    this.city,
    this.timezone,
    this.localTime,
    this.temperature,
    this.weatherCondition,
    this.weatherIcon,
  });

  factory WidgetPerson.fromJson(
    Map<String, dynamic> json,
  ) {
    return WidgetPerson(
      id: json['id'] as int,
      nickname: json['nickname'] as String,
      city: json['city'] as String?,
      timezone: json['timezone'] as String?,
      localTime: json['localTime'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      weatherCondition: json['weatherCondition'] as String?,
      weatherIcon: json['weatherIcon'] as String?,
    );
  }
}
