import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String chatChannelId = 'couplead_chat';

  static const String chatChannelName = '채팅 알림';

  Future<void> initialize() async {
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
      onDidReceiveNotificationResponse: (response) {
        /*
         * 다음 단계:
         * payload의 coupleId를 읽어서
         * 채팅방으로 이동
         */
      },
    );

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
}
