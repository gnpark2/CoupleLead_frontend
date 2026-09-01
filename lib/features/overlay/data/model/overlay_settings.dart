class OverlaySettings {
  final bool showAnniversary;
  final int? anniversaryId;

  final bool showMyTime;
  final bool showPartnerTime;

  final bool showMyWeather;
  final bool showPartnerWeather;

  const OverlaySettings({
    this.showAnniversary = true,
    this.anniversaryId,
    this.showMyTime = true,
    this.showPartnerTime = true,
    this.showMyWeather = true,
    this.showPartnerWeather = true,
  });

  OverlaySettings copyWith({
    bool? showAnniversary,
    int? anniversaryId,
    bool? clearAnniversaryId,
    bool? showMyTime,
    bool? showPartnerTime,
    bool? showMyWeather,
    bool? showPartnerWeather,
  }) {
    return OverlaySettings(
      showAnniversary: showAnniversary ?? this.showAnniversary,
      anniversaryId: clearAnniversaryId == true
          ? null
          : anniversaryId ?? this.anniversaryId,
      showMyTime: showMyTime ?? this.showMyTime,
      showPartnerTime: showPartnerTime ?? this.showPartnerTime,
      showMyWeather: showMyWeather ?? this.showMyWeather,
      showPartnerWeather: showPartnerWeather ?? this.showPartnerWeather,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showAnniversary': showAnniversary,
      'anniversaryId': anniversaryId,
      'showMyTime': showMyTime,
      'showPartnerTime': showPartnerTime,
      'showMyWeather': showMyWeather,
      'showPartnerWeather': showPartnerWeather,
    };
  }

  factory OverlaySettings.fromJson(
    Map<String, dynamic> json,
  ) {
    return OverlaySettings(
      showAnniversary: json['showAnniversary'] as bool? ?? true,
      anniversaryId: json['anniversaryId'] as int?,
      showMyTime: json['showMyTime'] as bool? ?? true,
      showPartnerTime: json['showPartnerTime'] as bool? ?? true,
      showMyWeather: json['showMyWeather'] as bool? ?? true,
      showPartnerWeather: json['showPartnerWeather'] as bool? ?? true,
    );
  }
}
