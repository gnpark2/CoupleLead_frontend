enum MediaOverlayLayout {
  equal,
  mainOnly,
  mainWithThumbnails,
}

class MediaOverlaySettings {
  final MediaOverlayLayout layout;

  /*
   * 메인으로 선택한 screen share track의 식별자.
   *
   * 처음에는 null이어도 되고,
   * 화면이 하나 이상 들어오면 첫 번째를 사용한다.
   */
  final String? mainTrackId;

  const MediaOverlaySettings({
    this.layout = MediaOverlayLayout.equal,
    this.mainTrackId,
  });

  MediaOverlaySettings copyWith({
    MediaOverlayLayout? layout,
    String? mainTrackId,
    bool clearMainTrackId = false,
  }) {
    return MediaOverlaySettings(
      layout: layout ?? this.layout,
      mainTrackId: clearMainTrackId ? null : mainTrackId ?? this.mainTrackId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'layout': layout.name,
      'mainTrackId': mainTrackId,
    };
  }

  factory MediaOverlaySettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final layoutName = json['layout']?.toString();

    final layout = MediaOverlayLayout.values
            .where(
              (
                value,
              ) =>
                  value.name == layoutName,
            )
            .firstOrNull ??
        MediaOverlayLayout.equal;

    return MediaOverlaySettings(
      layout: layout,
      mainTrackId: json['mainTrackId']?.toString(),
    );
  }
}
