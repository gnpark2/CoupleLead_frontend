class NotificationSettings {
  final bool chatNotificationEnabled;
  final bool soundEnabled;

  const NotificationSettings({
    this.chatNotificationEnabled = true,
    this.soundEnabled = true,
  });

  NotificationSettings copyWith({
    bool? chatNotificationEnabled,
    bool? soundEnabled,
  }) {
    return NotificationSettings(
      chatNotificationEnabled:
          chatNotificationEnabled ?? this.chatNotificationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatNotificationEnabled': chatNotificationEnabled,
      'soundEnabled': soundEnabled,
    };
  }

  factory NotificationSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    return NotificationSettings(
      chatNotificationEnabled: json['chatNotificationEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
    );
  }
}
