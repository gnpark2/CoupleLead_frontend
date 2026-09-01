import 'widget_person.dart';

class CoupleWidget {
  final int coupleId;
  final int daysTogether;

  final int partnerId;

  final int? anniversaryId;
  final String? anniversaryTitle;
  final String? anniversaryDate;
  final int? anniversaryDDay;

  final String partnerNickname;

  final bool partnerOnline;
  final bool partnerTyping;

  final String? partnerLastSeen;
  final String? partnerProfileImage;

  final int unreadCount;

  final String? partnerCity;
  final String? partnerTimezone;
  final String? partnerLocalTime;

  final double? temperature;
  final String? weatherCondition;
  final String? weatherIcon;

  final String? lastMessageAt;

  final WidgetPerson? me;
  final WidgetPerson? partner;

  const CoupleWidget({
    required this.coupleId,
    required this.partnerId,
    required this.daysTogether,
    this.anniversaryId,
    this.anniversaryTitle,
    this.anniversaryDate,
    this.anniversaryDDay,
    required this.partnerNickname,
    required this.partnerProfileImage,
    required this.partnerOnline,
    required this.partnerTyping,
    this.partnerLastSeen,
    required this.unreadCount,
    this.partnerCity,
    this.partnerTimezone,
    this.partnerLocalTime,
    this.temperature,
    this.weatherCondition,
    this.weatherIcon,
    this.lastMessageAt,
    this.me,
    this.partner,
  });

  factory CoupleWidget.fromJson(
    Map<String, dynamic> json,
  ) {
    return CoupleWidget(
      coupleId: (json['coupleId'] as num).toInt(),
      partnerId: (json['partnerId'] as num).toInt(),
      daysTogether: (json['daysTogether'] as num?)?.toInt() ?? 0,
      anniversaryId: (json['anniversaryId'] as num?)?.toInt(),
      anniversaryTitle: json['anniversaryTitle'] as String?,
      anniversaryDate: json['anniversaryDate'] as String?,
      anniversaryDDay: (json['anniversaryDDay'] as num?)?.toInt(),
      partnerNickname: json['partnerNickname'] as String? ?? '',
      partnerProfileImage: json['partnerProfileImage'] as String?,
      partnerOnline: json['partnerOnline'] as bool? ?? false,
      partnerTyping: json['partnerTyping'] as bool? ?? false,
      partnerLastSeen: json['partnerLastSeen'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      partnerCity: json['partnerCity'] as String?,
      partnerTimezone: json['partnerTimezone'] as String?,
      partnerLocalTime: json['partnerLocalTime'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      weatherCondition: json['weatherCondition'] as String?,
      weatherIcon: json['weatherIcon'] as String?,
      lastMessageAt: json['lastMessageAt'] as String?,
      me: json['me'] == null
          ? null
          : WidgetPerson.fromJson(
              Map<String, dynamic>.from(
                json['me'] as Map,
              ),
            ),
      partner: json['partner'] == null
          ? null
          : WidgetPerson.fromJson(
              Map<String, dynamic>.from(
                json['partner'] as Map,
              ),
            ),
    );
  }
}
