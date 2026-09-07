import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String chatChannelId = 'couplead_chat';

  static const String chatChannelName = '채팅 알림';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize({
    void Function(String? payload)? onNotificationTap,
  }) async {
    const windows = WindowsInitializationSettings(
      appName: 'Couplead',
      appUserModelId: 'Couplead.Desktop.App',
      guid: 'a8b44d95-f31a-4a70-a0e1-45856d31c102',
    );

    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const ios = DarwinInitializationSettings();

    const settings = InitializationSettings(
      windows: windows,
      android: android,
      iOS: ios,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (
        response,
      ) {
        onNotificationTap?.call(
          response.payload,
        );
      },
    );

    /*
     * Android 채팅 notification channel.
     *
     * AndroidManifest.xml의
     * default_notification_channel_id와
     * 반드시 같은 ID 사용.
     */
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        chatChannelId,
        chatChannelName,
        description: 'Couplead 채팅 메시지 알림',
        importance: Importance.high,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            channel,
          );
    }
  }

  /*
   * 기존 Windows 알림.
   *
   * 기존 기능 보호를 위해 수정하지 않는다.
   */
  Future<void> showChatNotification({
    required String nickname,
    required String message,
    required int coupleId,
  }) async {
    if (!Platform.isWindows) {
      return;
    }

    const details = NotificationDetails(
      windows: WindowsNotificationDetails(
        subtitle: '새 메시지',
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(
            2147483647,
          ),
      title: nickname,
      body: message,
      payload: 'chat:$coupleId',
      notificationDetails: details,
    );
  }

  /*
   * Android foreground 채팅 알림 전용.
   */
  Future<void> showAndroidChatNotification({
    required String nickname,
    required String message,
    required int coupleId,
    required int senderId,
    required bool soundEnabled,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    /*
     * navigation에 필요한 정보만 payload로 저장.
     */
    final payload = jsonEncode({
      'type': 'CHAT_MESSAGE',
      'coupleId': coupleId,
      'senderId': senderId,
      'senderNickname': nickname,
    });

    final androidDetails = AndroidNotificationDetails(
      chatChannelId,
      chatChannelName,
      channelDescription: 'Couplead 채팅 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      playSound: soundEnabled,
    );

    final details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(
            2147483647,
          ),
      title: nickname,
      body: message,
      payload: payload,
      notificationDetails: details,
    );
  }

  /*
   * local notification을 눌러
   * 앱이 시작된 경우 확인용.
   */
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();

    if (details?.didNotificationLaunchApp != true) {
      return null;
    }

    return details?.notificationResponse?.payload;
  }
}
