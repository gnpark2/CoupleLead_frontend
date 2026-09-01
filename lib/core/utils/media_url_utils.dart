import '../constants/api_constants.dart';

class MediaUrlUtils {
  MediaUrlUtils._();

  static String resolveChatImage(
    String image,
  ) {
    if (image.isEmpty) {
      return image;
    }

    /*
     * 이미 완전한 URL이면 그대로 사용
     */
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }

    final baseUrl = ApiConstants.baseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );

    /*
     * 새로운 S3 방식
     *
     * DB:
     * chat/abc.jpg
     *
     * 실제 조회 API:
     * /api/media/chat/abc.jpg
     */
    if (image.startsWith('chat/')) {
      final filename = image.substring(
        'chat/'.length,
      );

      return '$baseUrl/api/media/chat/$filename';
    }

    /*
     * 기존 로컬 저장 방식 하위 호환
     *
     * /uploads/chat/abc.jpg
     */
    if (image.startsWith('/uploads/')) {
      return '$baseUrl$image';
    }

    if (image.startsWith('uploads/')) {
      return '$baseUrl/$image';
    }

    /*
     * 그 외 상대 경로
     */
    if (image.startsWith('/')) {
      return '$baseUrl$image';
    }

    return '$baseUrl/$image';
  }
}
