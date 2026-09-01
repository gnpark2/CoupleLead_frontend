import '../config/app_config.dart';

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = AppConfig.apiBaseUrl;

  static const String wsUrl = AppConfig.wsUrl;

  static const String login = '/api/auth/login';
  static const String signup = '/api/auth/signup';
  static const String reissue = '/api/auth/reissue';
  static const String logout = '/api/auth/logout';

  static const String me = '/api/users/me';

  static const String myCouple = '/api/couples/me';
  static const String coupleWidget = '/api/widgets/couple';

  static const String selectWidgetAnniversary = '/api/widgets/anniversary';

  static const String chatSend = '/pub/chat/send';
  static const String chatTyping = '/pub/chat/typing';

  static const String webLogout = '/api/auth/web/logout';

  static const String coupleInvite = '/api/couples/invite';

  static const String coupleConnect = '/api/couples/connect';

  static const String mediaToken = '/api/media/token';

  static const String mediaInvite = '/api/media/invite';

  static const String mediaAccept = '/api/media/accept';

  static const String mediaReject = '/api/media/reject';

  static const mediaLeave = '/api/media/leave';

  static const String changePassword = '/api/users/me/password';

  static String chatMessages(int coupleId) => '/api/chat/$coupleId';
  static String chatRead(int coupleId) => '/api/chat/$coupleId/read';
  static String chatTopic(int coupleId) => '/topic/chat/$coupleId';
  static String chatReadTopic(int coupleId) => '/topic/chat/read/$coupleId';
  static String chatTypingTopic(int coupleId) => '/topic/chat/typing/$coupleId';
  static String chatDeleteTopic(int coupleId) => '/topic/chat/delete/$coupleId';
  static String chatAnnouncementTopic(int coupleId) =>
      '/topic/chat/announcement/$coupleId';
  static String chatEditTopic(
    int coupleId,
  ) =>
      '/topic/chat/edit/$coupleId';
  static String coupleUserTopic(
    int userId,
  ) =>
      '/topic/couple/user/$userId';
  static String mediaUserTopic(
    int userId,
  ) =>
      '/topic/media/user/$userId';
}
