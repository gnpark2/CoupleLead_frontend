import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import 'model/chat_announcement.dart';
import 'model/chat_history_page.dart';
import 'model/chat_image_upload_result.dart';
import 'model/chat_message.dart';
import 'model/chat_search_page.dart';
import 'model/chat_search_result.dart';
import 'model/chat_unread_boundary.dart';
import 'model/pending_chat_image.dart';

class ChatApi {
  final Dio dio;

  ChatApi({
    required this.dio,
  });

  Future<ChatHistoryPage> getMessages(
    int coupleId, {
    int? beforeMessageId,
    int size = 50,
  }) async {
    final response = await dio.get(
      ApiConstants.chatMessages(
        coupleId,
      ),
      queryParameters: {
        'size': size,
        if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
      },
    );

    final body = response.data as Map<String, dynamic>;

    final data = body['data'] as Map<String, dynamic>;

    return ChatHistoryPage.fromJson(
      data,
    );
  }

  Future<void> markAsRead(
    int coupleId,
  ) async {
    final path = ApiConstants.chatRead(
      coupleId,
    );

    debugPrint(
      '========== MARK AS READ API ==========',
    );

    debugPrint(
      'path=$path',
    );

    try {
      final response = await dio.post(
        path,
      );

      debugPrint(
        'MARK AS READ RESPONSE '
        'status=${response.statusCode}',
      );

      debugPrint(
        'MARK AS READ RESPONSE '
        'data=${response.data}',
      );
    } on DioException catch (e) {
      debugPrint(
        'MARK AS READ DIO ERROR',
      );

      debugPrint(
        'uri=${e.requestOptions.uri}',
      );

      debugPrint(
        'method=${e.requestOptions.method}',
      );

      debugPrint(
        'status=${e.response?.statusCode}',
      );

      debugPrint(
        'response=${e.response?.data}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        'MARK AS READ ERROR: $e',
      );

      rethrow;
    }
  }

  Future<String> uploadChatImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    final response = await dio.post(
      '/api/chat/images',
      data: formData,
    );

    final data = response.data['data'];

    return data['imageUrl'] as String;
  }

  Future<void> deleteMessage(
    int messageId,
  ) async {
    await dio.delete(
      '/api/chat/messages/$messageId',
    );
  }

  Future<void> editMessage({
    required int messageId,
    required String content,
  }) async {
    await dio.patch(
      '/api/chat/messages/$messageId',
      data: {
        'content': content,
      },
    );
  }

  Future<ChatSearchPage> searchMessages({
    required int coupleId,
    required String keyword,
    required bool useNori,
    int size = 20,
    DateTime? beforeSentAt,
    int? beforeMessageId,
    int? senderId,
    ChatMessageType? type,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await dio.get(
      '/api/chat/$coupleId/search',
      queryParameters: {
        'keyword': keyword,
        'useNori': useNori,
        'size': size,
        if (beforeSentAt != null)
          'beforeSentAt': beforeSentAt.toUtc().toIso8601String(),
        if (beforeMessageId != null) 'beforeMessageId': beforeMessageId,
        if (senderId != null) 'senderId': senderId,
        if (type != null)
          'type': switch (type) {
            ChatMessageType.text => 'TEXT',
            ChatMessageType.image => 'IMAGE',
          },
        if (fromDate != null) 'fromDate': _formatDate(fromDate),
        if (toDate != null) 'toDate': _formatDate(toDate),
      },
    );

    return ChatSearchPage.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<Uint8List> downloadChatImage(
    String imageUrl,
  ) async {
    final response = await dio.get<List<int>>(
      imageUrl,
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );

    final data = response.data;

    if (data == null) {
      throw Exception(
        '이미지를 다운로드하지 못했습니다.',
      );
    }

    return Uint8List.fromList(
      data,
    );
  }

  Future<ChatAnnouncement?> getAnnouncement(
    int coupleId,
  ) async {
    final response = await dio.get(
      '/api/chat/$coupleId/announcement',
    );

    final data = response.data['data'];

    if (data == null) {
      return null;
    }

    return ChatAnnouncement.fromJson(
      data as Map<String, dynamic>,
    );
  }

  Future<ChatAnnouncement> setAnnouncement({
    required int coupleId,
    required int messageId,
  }) async {
    final response = await dio.post(
      '/api/chat/$coupleId/announcement/$messageId',
    );

    return ChatAnnouncement.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<void> removeAnnouncement(
    int coupleId,
  ) async {
    await dio.delete(
      '/api/chat/$coupleId/announcement',
    );
  }

  Future<ChatUnreadBoundary> getUnreadBoundary(
    int coupleId,
  ) async {
    final response = await dio.get(
      '/api/chat/$coupleId/unread-boundary',
    );

    return ChatUnreadBoundary.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<List<ChatImageUploadResult>> uploadChatImages({
    required int coupleId,
    required List<PendingChatImage> images,
    required void Function(
      int sent,
      int total,
    ) onProgress,
  }) async {
    final formData = FormData();

    for (final image in images) {
      final bytes = image.compressedBytes ?? image.originalBytes;

      formData.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            bytes,
            filename: image.name,
          ),
        ),
      );
    }

    final response = await dio.post(
      '/api/chat/$coupleId/images',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onProgress,
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final imagesJson = data['images'] as List<dynamic>;

    return imagesJson
        .map(
          (json) => ChatImageUploadResult.fromJson(
            Map<String, dynamic>.from(
              json as Map,
            ),
          ),
        )
        .toList();
  }
}
