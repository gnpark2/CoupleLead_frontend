import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:public_file_saver/public_file_saver.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/media_url_utils.dart';
import '../../../core/widgets/authenticated_network_image.dart';
import '../../user/presentation/user_provider.dart';
import '../../widget/presentation/widget_provider.dart';
import '../../widget/presentation/widget_realtime_controller.dart';
import '../../widget/presentation/widget_realtime_key.dart';
import '../data/domain/ChatMessageSendStatus.dart';
import '../data/model/chat_announcement.dart';
import '../data/model/chat_message.dart';
import '../data/model/chat_search_result.dart';
import '../data/model/pending_chat_image.dart';
import 'chat_announcement_provider.dart';
import 'chat_image_viewer_page.dart';
import 'chat_messages_controller.dart';
import 'chat_provider.dart';
import 'chat_realtime_controller.dart';
import 'chat_realtime_state.dart';
import 'chat_image_editor_page.dart';
import 'chat_visibility_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int coupleId;
  final int partnerId;
  final String partnerNickname;
  final String? partnerProfileImage;

  const ChatPage(
      {super.key,
      required this.coupleId,
      required this.partnerId,
      required this.partnerNickname,
      this.partnerProfileImage});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();

  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  bool _didInitialScroll = false;
  bool _initialScrollCompleted = false;
  bool _showNewMessageBanner = false;
  String? _latestIncomingContent;
  int _newMessageCount = 0;
  int? _highlightedMessageId;
  bool _showScrollToBottomButton = false;
  ChatMessage? _replyingToMessage;
  ChatMessage? _editingMessage;
  bool _showIncomingPreview = false;
  String? _incomingPreviewContent;
  Timer? _incomingPreviewTimer;
  bool _locatingMessage = false;
  int? _firstUnreadMessageId;
  int _initialUnreadCount = 0;
  bool _unreadBoundaryLoaded = false;
  List<PendingChatImage> _pendingImages = [];

  bool _uploadingImages = false;

  double _imageUploadProgress = 0;

  @override
  void initState() {
    super.initState();

    _itemPositionsListener.itemPositions.addListener(
      _onItemPositionsChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _initializeUnreadBoundary();
      },
    );

    Future.microtask(
      () {
        if (!mounted) {
          return;
        }

        ref
            .read(
              currentChatCoupleIdProvider.notifier,
            )
            .state = widget.coupleId;
      },
    );
  }

  @override
  void dispose() {
    _incomingPreviewTimer?.cancel();
    _messageController.dispose();
    _itemPositionsListener.itemPositions.removeListener(
      _onItemPositionsChanged,
    );

    Future.microtask(
      () {
        if (!mounted) {
          return;
        }

        ref
            .read(
              currentChatCoupleIdProvider.notifier,
            )
            .state = widget.coupleId;
      },
    );

    /*
     * STOMP disconnect 하지 않음
     */
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      await ref.read(chatApiProvider).markAsRead(
            widget.coupleId,
          );

      await ref.refresh(
        coupleWidgetProvider.future,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHAT PAGE READ ERROR: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  Future<void> _sendMessage(
    ChatRealtimeController controller,
  ) async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    /*
   * 수정 모드
   */
    if (_editingMessage != null) {
      final editing = _editingMessage!;

      try {
        await ref
            .read(
              chatApiProvider,
            )
            .editMessage(
              messageId: editing.id!,
              content: content,
            );

        if (!mounted) {
          return;
        }

        _messageController.clear();

        setState(() {
          _editingMessage = null;
        });

        /*
       * 본인 화면 즉시 갱신
       */
        await ref
            .read(
              chatMessagesControllerProvider(
                widget.coupleId,
              ).notifier,
            )
            .refreshLatest();
      } catch (e) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              '메시지 수정 실패: $e',
            ),
          ),
        );
      }

      return;
    }

    /*
   * 일반 메시지 / 답장
   */
    controller.sendMessage(
      content,
      replyToMessageId: _replyingToMessage?.id,
    );

    _messageController.clear();

    setState(() {
      _replyingToMessage = null;
    });

    _scrollToBottom();
  }

  Future<void> _showMessageContextMenu({
    required Offset position,
    required ChatMessage message,
    required bool isMine,
  }) async {
    if (message.deleted) {
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(
                Icons.reply,
                size: 20,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                '답장',
              ),
            ],
          ),
        ),
        if (message.type == ChatMessageType.text)
          const PopupMenuItem<String>(
            value: 'copy',
            child: Row(
              children: [
                Icon(
                  Icons.copy_outlined,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '복사',
                ),
              ],
            ),
          ),
        if (message.type == ChatMessageType.text)
          const PopupMenuItem<String>(
            value: 'announcement',
            child: Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '공지',
                ),
              ],
            ),
          ),
        if (message.type == ChatMessageType.image)
          const PopupMenuItem<String>(
            value: 'openImage',
            child: Row(
              children: [
                Icon(
                  Icons.open_in_full,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '이미지 열기',
                ),
              ],
            ),
          ),
        if (message.type == ChatMessageType.image)
          const PopupMenuItem<String>(
            value: 'saveImage',
            child: Row(
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '이미지 저장',
                ),
              ],
            ),
          ),
        if (isMine && message.type == ChatMessageType.text)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '수정',
                ),
              ],
            ),
          ),
        if (isMine)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '삭제',
                ),
              ],
            ),
          ),
      ],
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case 'reply':
        setState(() {
          _editingMessage = null;

          _replyingToMessage = message;
        });

        break;

      case 'copy':
        await Clipboard.setData(
          ClipboardData(
            text: message.content,
          ),
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              '메시지를 복사했습니다.',
            ),
            duration: Duration(
              seconds: 1,
            ),
          ),
        );

        break;

      case 'announcement':
        try {
          await ref
              .read(
                chatApiProvider,
              )
              .setAnnouncement(
                coupleId: widget.coupleId,
                messageId: message.id!,
              );

          await ref.refresh(
            chatAnnouncementProvider(
              widget.coupleId,
            ).future,
          );

          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                '공지로 등록했습니다.',
              ),
            ),
          );
        } catch (e) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(
                '공지 등록 실패: $e',
              ),
            ),
          );
        }

        break;

      case 'openImage':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatImageViewerPage.single(
              imageUrl: MediaUrlUtils.resolveChatImage(
                message.content,
              ),
            ),
          ),
        );

        break;

      case 'saveImage':
        await _saveChatImage(
          message,
        );

        break;

      case 'edit':
        setState(() {
          _replyingToMessage = null;

          _editingMessage = message;

          _messageController.text = message.content;

          _messageController.selection = TextSelection.collapsed(
            offset: _messageController.text.length,
          );
        });

        break;

      case 'delete':
        await _confirmDeleteMessage(
          message,
        );

        break;
    }
  }

  Future<void> _confirmDeleteMessage(
    ChatMessage message,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        context,
      ) {
        return AlertDialog(
          title: const Text(
            '메시지 삭제',
          ),
          content: const Text(
            '이 메시지를 모두에게 삭제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  false,
                );
              },
              child: const Text(
                '취소',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  true,
                );
              },
              child: const Text(
                '삭제',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(
            chatApiProvider,
          )
          .deleteMessage(
            message.id!,
          );

      /*
     * WebSocket 이벤트도 오지만
     * 본인 화면을 즉시 갱신
     */
      await ref
          .read(
            chatMessagesControllerProvider(
              widget.coupleId,
            ).notifier,
          )
          .refreshLatest();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '메시지 삭제 실패: $e',
          ),
        ),
      );
    }
  }

  Future<void> _saveChatImage(
    ChatMessage message,
  ) async {
    try {
      final bytes = await ref
          .read(
            chatApiProvider,
          )
          .downloadChatImage(
            message.content,
          );

      final uri = Uri.parse(
        message.content,
      );

      final originalName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'couplead-image.jpg';

      final extension = originalName.split('.').last.toLowerCase();

      final mimeType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      final fileName =
          'couplead_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await PublicFileSaver().saveBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            '이미지를 저장했습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '이미지 저장 실패: $e',
          ),
        ),
      );
    }
  }

  Future<void> _pickChatImages() async {
    if (_uploadingImages) {
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        limit: 10,
      );

      if (images.isEmpty) {
        return;
      }

      await _prepareChatImages(
        images,
      );
    } catch (e) {
      debugPrint(
        'PICK CHAT IMAGES ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '이미지를 불러오지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _prepareChatImages(
    List<XFile> files,
  ) async {
    final selected = files.take(10).toList();

    /*
   * 여러 장일 때만 같은 groupId 사용
   */
    final String? mediaGroupId = selected.length > 1 ? _uuid.v4() : null;

    setState(() {
      _pendingImages = [];
    });

    for (final file in selected) {
      final originalBytes = await file.readAsBytes();

      /*
     * 압축 중인 이미지를 먼저 UI에 표시
     */
      final index = _pendingImages.length;

      setState(() {
        _pendingImages.add(PendingChatImage(
          name: _normalizeImageName(
            file.name,
            index,
          ),
          originalBytes: originalBytes,
          status: ChatImageUploadStatus.compressing,
          mediaGroupId: mediaGroupId,

          /*
   * 이미지마다 별도의 메시지 UUID
   */
          clientMessageId: _uuid.v4(),
        ));
      });

      try {
        final compressed = await FlutterImageCompress.compressWithList(
          originalBytes,

          /*
         * 채팅 이미지에는 이 정도가 적당.
         * 긴 변 기준 약 1920px
         */
          minWidth: 1920,
          minHeight: 1920,

          /*
         * JPEG/WebP quality.
         */
          quality: 82,

          /*
         * 위치정보 등 EXIF 제거.
         * 채팅 이미지에서는 개인정보 측면에서도
         * keepExif=false가 좋음.
         */
          keepExif: false,
        );

        if (!mounted) {
          return;
        }

        /*
       * 오히려 압축 결과가 더 크면
       * 원본 사용
       */
        final resultBytes = compressed.length < originalBytes.length
            ? Uint8List.fromList(
                compressed,
              )
            : originalBytes;

        setState(() {
          _pendingImages[index] = _pendingImages[index].copyWith(
            compressedBytes: resultBytes,
            status: ChatImageUploadStatus.ready,
          );
        });
      } catch (e) {
        debugPrint(
          'IMAGE COMPRESS ERROR: $e',
        );

        /*
       * 압축에 실패하더라도
       * 원본으로 업로드 가능
       */
        if (!mounted) {
          return;
        }

        setState(() {
          _pendingImages[index] = _pendingImages[index].copyWith(
            compressedBytes: originalBytes,
            status: ChatImageUploadStatus.ready,
          );
        });
      }
    }
  }

  String _normalizeImageName(
    String originalName,
    int index,
  ) {
    final dotIndex = originalName.lastIndexOf('.');

    final extension = dotIndex >= 0
        ? originalName.substring(
            dotIndex,
          )
        : '.jpg';

    return 'chat_${DateTime.now().millisecondsSinceEpoch}_'
        '$index$extension';
  }

  Future<void> _uploadPendingImages(
    ChatRealtimeController realtimeController,
  ) async {
    if (_uploadingImages) {
      return;
    }

    final readyImages = _pendingImages
        .where(
          (image) =>
              image.status == ChatImageUploadStatus.ready &&
              image.compressedBytes != null,
        )
        .toList();

    if (readyImages.isEmpty) {
      return;
    }

    setState(() {
      _uploadingImages = true;
      _imageUploadProgress = 0;
    });

    int completedCount = 0;

    final replyToMessageId = _replyingToMessage?.id;

    /*
   * TEST ONLY
   */
    // int testIndex = 0;

    try {
      for (final image in readyImages) {
        // testIndex++;

        final index = _pendingImages.indexWhere(
          (item) => item.clientMessageId == image.clientMessageId,
        );

        if (index < 0) {
          continue;
        }

        /*
       * ready → uploading
       */
        if (mounted) {
          setState(() {
            _pendingImages[index] = _pendingImages[index].copyWith(
              status: ChatImageUploadStatus.uploading,
            );
          });
        }

        /*
       * ★ 여기서부터 개별 이미지 try
       */
        try {
          /*
         * TEST ONLY
         *
         * 반드시 이 try 안에 있어야 한다.
         */
          // if (testIndex == 2) {
          //   throw Exception(
          //     'TEST HTTP UPLOAD FAILURE',
          //   );
          // }

          /*
         * HTTP 개별 업로드
         */
          final imageUrl = await _uploadSinglePendingImage(
            image,
          );

          /*
         * HTTP 성공 후
         * STOMP IMAGE 메시지 전송
         */
          realtimeController.sendImage(
            imageUrl,
            replyToMessageId: replyToMessageId,
            mediaGroupId: image.mediaGroupId,
            clientMessageId: image.clientMessageId,
          );

          if (!mounted) {
            return;
          }

          /*
         * HTTP 성공한 이미지는
         * pending preview에서 제거
         */
          setState(() {
            _pendingImages.removeWhere(
              (item) => item.clientMessageId == image.clientMessageId,
            );
          });
        } catch (e) {
          debugPrint(
            'IMAGE HTTP UPLOAD FAILED '
            '${image.name}: $e',
          );

          if (!mounted) {
            return;
          }

          final failedIndex = _pendingImages.indexWhere(
            (item) => item.clientMessageId == image.clientMessageId,
          );

          if (failedIndex >= 0) {
            setState(() {
              _pendingImages[failedIndex] =
                  _pendingImages[failedIndex].copyWith(
                status: ChatImageUploadStatus.failed,
              );
            });
          }
        } finally {
          completedCount++;

          if (mounted) {
            setState(() {
              _imageUploadProgress = completedCount / readyImages.length;
            });
          }
        }
      }

      if (!mounted) {
        return;
      }

      final failedCount = _pendingImages
          .where(
            (image) => image.status == ChatImageUploadStatus.failed,
          )
          .length;

      if (failedCount == 0) {
        setState(() {
          _replyingToMessage = null;
        });

        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              '$failedCount장의 이미지 업로드에 실패했습니다.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImages = false;
        });
      }
    }
  }

  Future<void> _removeAnnouncement() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        context,
      ) {
        return AlertDialog(
          title: const Text(
            '공지 해제',
          ),
          content: const Text(
            '현재 공지를 해제할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  false,
                );
              },
              child: const Text(
                '취소',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  true,
                );
              },
              child: const Text(
                '공지 해제',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(
            chatApiProvider,
          )
          .removeAnnouncement(
            widget.coupleId,
          );

      /*
     * WebSocket도 오지만
     * 본인 화면 즉시 갱신
     */
      ref.invalidate(
        chatAnnouncementProvider(
          widget.coupleId,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            '공지를 해제했습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '공지 해제 실패: $e',
          ),
        ),
      );
    }
  }

  void _showLatestMessagePreview(
    String content,
  ) {
    _incomingPreviewTimer?.cancel();

    setState(() {
      _showIncomingPreview = true;

      _incomingPreviewContent = content;
    });

    _incomingPreviewTimer = Timer(
      const Duration(
        seconds: 3,
      ),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _showIncomingPreview = false;

          _incomingPreviewContent = null;
        });
      },
    );
  }

  void _jumpToLatest() {
    final state = ref.read(
      chatMessagesControllerProvider(
        widget.coupleId,
      ),
    );

    final messages = state.messages;

    if (messages.isEmpty) {
      return;
    }

    /*
   * 첫 번째 frame에서
   * ScrollablePositionedList가 배치될 때까지 기다림
   */
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        /*
       * 한 frame을 한 번 더 기다려
       * 공지/입력창 등의 높이까지
       * 최종 반영되게 함
       */
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (!mounted || !_itemScrollController.isAttached) {
              return;
            }

            final latestState = ref.read(
              chatMessagesControllerProvider(
                widget.coupleId,
              ),
            );

            if (latestState.messages.isEmpty) {
              return;
            }

            final lastIndex = latestState.messages.length - 1;

            _itemScrollController.jumpTo(
              index: lastIndex,

              /*
             * 마지막 메시지가
             * 화면 아래쪽 안에 확실히 보이게
             */
              alignment: 0.9,
            );
          },
        );
      },
    );
  }

  Future<void> _showChatSearch({
    required int myUserId,
    required String partnerNickname,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (
        context,
      ) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: _ChatSearchSheet(
            coupleId: widget.coupleId,
            myUserId: myUserId,
            partnerId: widget.partnerId,
            partnerNickname: partnerNickname,
            onMessageSelected: (
              messageId,
            ) {
              Navigator.of(
                context,
              ).pop();

              WidgetsBinding.instance.addPostFrameCallback(
                (_) async {
                  await _goToMessage(
                    messageId,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<int?> _ensureMessageLoaded(
    int messageId,
  ) async {
    const maxLoadAttempts = 20;

    final controller = ref.read(
      chatMessagesControllerProvider(
        widget.coupleId,
      ).notifier,
    );

    for (int attempt = 0; attempt < maxLoadAttempts; attempt++) {
      final index = controller.indexOfMessage(
        messageId,
      );

      if (index >= 0) {
        return index;
      }

      final chatState = ref.read(
        chatMessagesControllerProvider(
          widget.coupleId,
        ),
      );

      if (!chatState.hasMore) {
        return null;
      }

      await controller.loadMore();
    }

    return null;
  }

  int _resolveMediaGroupIndex(
    List<ChatMessage> messages,
    int index,
  ) {
    if (index < 0 || index >= messages.length) {
      return index;
    }

    final message = messages[index];

    final groupId = message.mediaGroupId;

    if (groupId == null || groupId.isEmpty) {
      return index;
    }

    for (int i = index; i >= 0; i--) {
      if (messages[i].mediaGroupId != groupId) {
        return i + 1;
      }
    }

    return 0;
  }

  void _retryMessage(
    ChatMessage message,
    ChatRealtimeController realtimeController,
  ) {
    realtimeController.retryMessage(
      message,
    );

    _scrollToBottom();
  }

  Future<void> _initializeUnreadBoundary() async {
    try {
      /*
     * markAsRead()보다 먼저
     * unread 위치를 기억한다.
     */
      final boundary = await ref
          .read(
            chatApiProvider,
          )
          .getUnreadBoundary(
            widget.coupleId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _firstUnreadMessageId = boundary.firstUnreadMessageId;

        _initialUnreadCount = boundary.unreadCount;

        _unreadBoundaryLoaded = true;
      });

      /*
     * 위치를 기억한 뒤
     * 서버 읽음 처리.
     */
      await _markAsRead();
    } catch (e) {
      debugPrint(
        'UNREAD BOUNDARY ERROR: $e',
      );

      if (mounted) {
        setState(() {
          _unreadBoundaryLoaded = true;
        });
      }

      await _markAsRead();
    }
  }

  List<ChatMessage> _getMediaGroup(
    List<ChatMessage> messages,
    int index,
  ) {
    final message = messages[index];

    final groupId = message.mediaGroupId;

    if (message.type != ChatMessageType.image ||
        groupId == null ||
        groupId.isEmpty) {
      return [
        message,
      ];
    }

    return messages
        .where(
          (item) =>
              item.type == ChatMessageType.image &&
              item.mediaGroupId == groupId &&
              !item.deleted,
        )
        .toList();
  }

  bool _isFirstOfMediaGroup(
    List<ChatMessage> messages,
    int index,
  ) {
    final current = messages[index];

    final groupId = current.mediaGroupId;

    if (groupId == null || groupId.isEmpty) {
      return true;
    }

    /*
   * 현재 메시지가 삭제됐다면
   * 그룹 대표로 사용하지 않음
   */
    if (current.deleted) {
      return false;
    }

    /*
   * 앞쪽에서 같은 그룹의
   * 삭제되지 않은 이미지가 존재하는지 확인
   */
    for (int i = index - 1; i >= 0; i--) {
      final previous = messages[i];

      if (previous.mediaGroupId != groupId) {
        break;
      }

      if (!previous.deleted) {
        return false;
      }
    }

    return true;
  }

  Future<void> _editPendingImage(
    int index,
  ) async {
    if (_uploadingImages) {
      return;
    }

    if (index < 0 || index >= _pendingImages.length) {
      return;
    }

    final image = _pendingImages[index];

    /*
   * 현재 화면에 보여주고 있는 이미지를
   * 편집기로 전달한다.
   *
   * 이미 압축된 이미지가 있으면 그것을 사용하고,
   * 없으면 원본 사용.
   */
    final bytes = image.compressedBytes ?? image.originalBytes;

    final editedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ChatImageEditorPage(
          imageBytes: bytes,
        ),
      ),
    );

    /*
   * 편집 취소
   */
    if (editedBytes == null || !mounted) {
      return;
    }

    /*
   * 편집 직후 압축 중 상태로 변경
   */
    setState(() {
      _pendingImages[index] = _pendingImages[index].copyWith(
        status: ChatImageUploadStatus.compressing,
      );
    });

    try {
      /*
     * 편집 결과를 다시 압축
     */
      final compressed = await FlutterImageCompress.compressWithList(
        editedBytes,
        minWidth: 1920,
        minHeight: 1920,
        quality: 82,
        keepExif: false,
      );

      if (!mounted) {
        return;
      }

      /*
     * 압축한 결과가 오히려 더 크면
     * 편집 결과 그대로 사용
     */
      final resultBytes = compressed.length < editedBytes.length
          ? Uint8List.fromList(
              compressed,
            )
          : editedBytes;

      setState(() {
        _pendingImages[index] = _pendingImages[index].copyWith(
          compressedBytes: resultBytes,
          status: ChatImageUploadStatus.ready,
        );
      });
    } catch (e) {
      debugPrint(
        'EDIT IMAGE COMPRESS ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      /*
     * 압축 실패 시 편집 결과 그대로 사용
     */
      setState(() {
        _pendingImages[index] = _pendingImages[index].copyWith(
          compressedBytes: editedBytes,
          status: ChatImageUploadStatus.ready,
        );
      });
    }
  }

  void _reorderPendingImages(
    int oldIndex,
    int newIndex,
  ) {
    if (_uploadingImages) {
      return;
    }

    /*
   * 업로드 중인 이미지가 하나라도 있으면
   * 순서 변경 금지
   */
    final hasUploading = _pendingImages.any(
      (image) => image.status == ChatImageUploadStatus.uploading,
    );

    if (hasUploading) {
      return;
    }

    setState(() {
      /*
     * ReorderableListView 규칙
     *
     * 뒤쪽으로 이동할 때는
     * remove 이후 index가 하나 줄어든다.
     */
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final image = _pendingImages.removeAt(
        oldIndex,
      );

      _pendingImages.insert(
        newIndex,
        image,
      );
    });
  }

  Future<void> _retryPendingImageUpload(
    int index,
    ChatRealtimeController realtimeController,
  ) async {
    if (_uploadingImages) {
      return;
    }

    if (index < 0 || index >= _pendingImages.length) {
      return;
    }

    final image = _pendingImages[index];

    if (image.status != ChatImageUploadStatus.failed) {
      return;
    }

    /*
   * 현재 답장 대상 저장
   */
    final replyToMessageId = _replyingToMessage?.id;

    setState(() {
      _pendingImages[index] = image.copyWith(
        status: ChatImageUploadStatus.uploading,
      );
    });

    try {
      /*
     * 실패했던 이 이미지 하나만
     * 다시 HTTP 업로드
     */
      final imageUrl = await _uploadSinglePendingImage(
        image,
      );

      /*
     * 성공하면 STOMP IMAGE 전송
     *
     * 기존 group/client ID 유지
     */
      realtimeController.sendImage(
        imageUrl,
        replyToMessageId: replyToMessageId,
        mediaGroupId: image.mediaGroupId,
        clientMessageId: image.clientMessageId,
      );

      if (!mounted) {
        return;
      }

      /*
     * 성공한 pending 이미지 제거
     */
      setState(() {
        _pendingImages.removeWhere(
          (item) => item.clientMessageId == image.clientMessageId,
        );

        if (_pendingImages.isEmpty) {
          _replyingToMessage = null;
        }
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint(
        'IMAGE RETRY UPLOAD FAILED: $e',
      );

      if (!mounted) {
        return;
      }

      /*
     * 다시 failed
     */
      final failedIndex = _pendingImages.indexWhere(
        (item) => item.clientMessageId == image.clientMessageId,
      );

      if (failedIndex >= 0) {
        setState(() {
          _pendingImages[failedIndex] = _pendingImages[failedIndex].copyWith(
            status: ChatImageUploadStatus.failed,
          );
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            '이미지 재업로드에 실패했습니다.',
          ),
        ),
      );
    }
  }

//////////////////////////////////////////////////////////////////////////

  bool _isNearBottom() {
    final positions = _itemPositionsListener.itemPositions.value;

    if (positions.isEmpty) {
      return true;
    }

    final messages = ref
        .read(
          chatMessagesControllerProvider(
            widget.coupleId,
          ),
        )
        .messages;

    if (messages.isEmpty) {
      return true;
    }

    final lastVisibleIndex = positions
        .where(
          (position) =>
              position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1,
        )
        .map(
          (position) => position.index,
        )
        .fold<int>(
          0,
          (max, index) => index > max ? index : max,
        );

    return lastVisibleIndex >= messages.length - 2;
  }

  void _scrollToBottom() {
    final messages = ref
        .read(
          chatMessagesControllerProvider(
            widget.coupleId,
          ),
        )
        .messages;

    if (messages.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted || !_itemScrollController.isAttached) {
          return;
        }

        final latestMessages = ref
            .read(
              chatMessagesControllerProvider(
                widget.coupleId,
              ),
            )
            .messages;

        if (latestMessages.isEmpty) {
          return;
        }

        _itemScrollController.scrollTo(
          index: latestMessages.length - 1,
          duration: const Duration(
            milliseconds: 300,
          ),
          curve: Curves.easeOut,
          alignment: 0.9,
        );
      },
    );
  }

  Future<void> _onItemPositionsChanged() async {
    if (!_initialScrollCompleted) {
      return;
    }

    final positions = _itemPositionsListener.itemPositions.value;

    if (positions.isEmpty) {
      return;
    }

    /*
   * 실제 화면에 보이는 index
   */
    final visiblePositions = positions.where(
      (position) =>
          position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1,
    );

    if (visiblePositions.isEmpty) {
      return;
    }

    final firstVisibleIndex = visiblePositions
        .map(
          (e) => e.index,
        )
        .reduce(
          (a, b) => a < b ? a : b,
        );

    final shouldShowBottomButton = !_isNearBottom();

    if (_showScrollToBottomButton != shouldShowBottomButton) {
      setState(() {
        _showScrollToBottomButton = shouldShowBottomButton;
      });
    }

    if (_showNewMessageBanner && _isNearBottom()) {
      setState(() {
        _showNewMessageBanner = false;
        _latestIncomingContent = null;
        _newMessageCount = 0;
      });
    }

    /*
   * 상단 2개 메시지 이내가 아니면
   * pagination 하지 않음
   */
    if (firstVisibleIndex > 2) {
      return;
    }

    final currentState = ref.read(
      chatMessagesControllerProvider(
        widget.coupleId,
      ),
    );

    if (currentState.loading ||
        currentState.loadingMore ||
        !currentState.hasMore ||
        currentState.nextCursor == null) {
      return;
    }

    final oldMessagesCount = currentState.messages.length;

    /*
   * 현재 가장 위에서 보이던 메시지를 기억
   */
    final firstVisibleMessageId = currentState.messages[firstVisibleIndex].id;

    await ref
        .read(
          chatMessagesControllerProvider(
            widget.coupleId,
          ).notifier,
        )
        .loadMore();

    if (!mounted) {
      return;
    }

    final newMessages = ref
        .read(
          chatMessagesControllerProvider(
            widget.coupleId,
          ),
        )
        .messages;

    /*
   * loadMore 때문에 앞쪽에 메시지가 추가돼도
   * 기존에 보고 있던 메시지 위치 유지
   */
    final newIndex = newMessages.indexWhere(
      (message) => message.id == firstVisibleMessageId,
    );

    if (newIndex >= 0 &&
        newMessages.length > oldMessagesCount &&
        _itemScrollController.isAttached) {
      _itemScrollController.jumpTo(
        index: newIndex,
      );
    }
  }

  Future<void> _goToMessage(
    int messageId,
  ) async {
    if (_locatingMessage) {
      return;
    }

    setState(() {
      _locatingMessage = true;
    });

    try {
      /*
     * 먼저 실제 검색된 메시지가
     * 현재 history에 들어올 때까지 loadMore
     */
      final loadedIndex = await _ensureMessageLoaded(
        messageId,
      );

      if (!mounted) {
        return;
      }

      if (loadedIndex == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              '해당 메시지를 찾을 수 없습니다.',
            ),
          ),
        );

        return;
      }

      final messages = ref
          .read(
            chatMessagesControllerProvider(
              widget.coupleId,
            ),
          )
          .messages;

      /*
     * 이미지 그룹 내부 메시지를 검색했다면
     * 그룹 첫 메시지 위치로 변경
     */
      final index = _resolveMediaGroupIndex(
        messages,
        loadedIndex,
      );

      /*
     * 화면에서 실제 렌더링되는
     * 메시지의 id.
     *
     * 일반 메시지:
     * 검색한 messageId와 동일
     *
     * 이미지 그룹:
     * 그룹 첫 이미지 messageId
     */
      final displayMessageId = messages[index].id;

      setState(() {
        _highlightedMessageId = displayMessageId;
      });

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (!_itemScrollController.isAttached) {
            return;
          }

          _itemScrollController.scrollTo(
            index: index,
            duration: const Duration(
              milliseconds: 350,
            ),
            curve: Curves.easeOutCubic,
            alignment: 0.35,
          );
        },
      );

      Future.delayed(
        const Duration(
          seconds: 2,
        ),
        () {
          if (mounted && _highlightedMessageId == displayMessageId) {
            setState(() {
              _highlightedMessageId = null;
            });
          }
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _locatingMessage = false;
        });
      }
    }
  }

//////////////////////////////////////////////////////////////////

  @override
  Widget build(
    BuildContext context,
  ) {
    final meAsync = ref.watch(meProvider);

    final me = meAsync.value;

    final coupleWidgetAsync = ref.watch(
      coupleWidgetProvider,
    );

    final coupleWidget = coupleWidgetAsync.value;

    final announcementAsync = ref.watch(
      chatAnnouncementProvider(
        widget.coupleId,
      ),
    );

    if (coupleWidget != null) {
      ref.watch(
        widgetRealtimeProvider(
          WidgetRealtimeKey(
            coupleId: coupleWidget.coupleId,
            partnerId: coupleWidget.partnerId,
          ),
        ),
      );
    }

    final latestCoupleWidget = coupleWidgetAsync.value;

    final partnerNickname =
        latestCoupleWidget?.partnerNickname ?? widget.partnerNickname;

    final partnerProfileImage =
        latestCoupleWidget?.partnerProfileImage ?? widget.partnerProfileImage;

    if (me == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // _initializeRead();

    final realtimeArgs = ChatRealtimeArgs(
      coupleId: widget.coupleId,
      myUserId: me.id,
      partnerId: widget.partnerId,
    );

    final realtimeProvider = chatRealtimeProvider(
      realtimeArgs,
    );

    final realtimeState = ref.watch(
      realtimeProvider,
    );

    final realtimeController = ref.read(
      realtimeProvider.notifier,
    );

    ref.listen<ChatRealtimeState>(
      realtimeProvider,
      (
        previous,
        next,
      ) {
        /*
     * typing, connected 등의 변경은 무시하고
     * 새 메시지 이벤트만 처리
     */
        if (previous?.incomingMessageVersion == next.incomingMessageVersion) {
          return;
        }

        final content = next.latestIncomingContent;

        if (content == null) {
          return;
        }

        /*
     * 메시지가 도착한 순간
     * 현재 사용자가 아래쪽을 보고 있었는지 확인
     */
        final wasNearBottom = _isNearBottom();

        if (wasNearBottom) {
          /*
   * 현재 최신 메시지를 보고 있었다면
   * 새 메시지를 화면에 보이게 이동
   */
          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              _scrollToBottom();
            },
          );

          /*
   * 입력창 위에서
   * 새 메시지 내용을 한 줄로 잠깐 표시
   */
          _showLatestMessagePreview(
            content,
          );

          if (_showNewMessageBanner) {
            setState(() {
              _showNewMessageBanner = false;

              _latestIncomingContent = null;

              _newMessageCount = 0;
            });
          }

          return;
        }

        /*
     * 과거 메시지를 보고 있었다면
     * 현재 위치를 그대로 유지하고
     * 새 메시지 배너 표시
     */
        setState(() {
          _showNewMessageBanner = true;

          _latestIncomingContent = content;

          _newMessageCount++;
        });
      },
    );

    final messagesState = ref.watch(
      chatMessagesControllerProvider(
        widget.coupleId,
      ),
    );

    final messages = messagesState.messages;

    final extraTopItem = messagesState.loadingMore ? 1 : 0;

    if (!messagesState.loading && messages.isNotEmpty && !_didInitialScroll) {
      _didInitialScroll = true;

      _jumpToLatest();

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) {
              if (mounted) {
                _initialScrollCompleted = true;
              }
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          partnerNickname,
        ),
        actions: [
          IconButton(
            tooltip: '채팅 검색',
            onPressed: () {
              _showChatSearch(
                myUserId: me.id,
                partnerNickname: partnerNickname,
              );
            },
            icon: const Icon(
              Icons.search,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          announcementAsync.when(
            data: (
              announcement,
            ) {
              if (announcement == null) {
                return const SizedBox.shrink();
              }

              return _ChatAnnouncementBar(
                announcement: announcement,
                onGoToMessage: () {
                  _goToMessage(announcement.messageId);
                },
                onRemove: () {
                  _removeAnnouncement();
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (
              _,
              __,
            ) =>
                const SizedBox.shrink(),
          ),
          Expanded(
            child: Builder(
              builder: (
                context,
              ) {
                if (messagesState.loading && messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (messagesState.error != null && messages.isEmpty) {
                  return Center(
                    child: Text(
                      '채팅을 불러오지 못했습니다.\n'
                      '${messagesState.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      '아직 메시지가 없습니다.',
                    ),
                  );
                }

                return ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemPositionsListener: _itemPositionsListener,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length + extraTopItem,
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    if (messagesState.loadingMore && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    final messageIndex = index - extraTopItem;

                    final message = messages[messageIndex];

                    final isImageGroup =
                        message.type == ChatMessageType.image &&
                            message.mediaGroupId != null &&
                            message.mediaGroupId!.isNotEmpty;

                    final isFirstMediaGroup = !isImageGroup ||
                        _isFirstOfMediaGroup(
                          messages,
                          messageIndex,
                        );

                    if (isImageGroup &&
                        (message.deleted || !isFirstMediaGroup)) {
                      return const SizedBox.shrink();
                    }

                    final List<ChatMessage> mediaGroup = isImageGroup
                        ? _getMediaGroup(
                            messages,
                            messageIndex,
                          )
                        : <ChatMessage>[];

                    final isMine = message.senderId == me.id;

                    final showDate = messageIndex == 0 ||
                        !_isSameDay(
                          messages[messageIndex - 1].sentAt,
                          message.sentAt,
                        );

                    final showUnreadDivider = _unreadBoundaryLoaded &&
                        _firstUnreadMessageId != null &&
                        message.id == _firstUnreadMessageId;

                    final isFirstMessageOfGroup = messageIndex == 0 ||
                        !_isSameMessageGroup(
                          messages[messageIndex - 1],
                          message,
                        );

                    final isLastMessageOfGroup =
                        messageIndex == messages.length - 1 ||
                            !_isSameMessageGroup(
                              message,
                              messages[messageIndex + 1],
                            );

                    return Column(
                      children: [
                        if (showDate)
                          _DateDivider(
                            date: message.sentAt,
                          ),
                        if (showUnreadDivider)
                          _UnreadDivider(
                            count: _initialUnreadCount,
                          ),
                        _MessageBubble(
                          message: message,
                          mediaGroup: mediaGroup,
                          isMine: isMine,
                          isFirstOfGroup: isFirstMessageOfGroup,
                          showProfile: !isMine && isFirstMessageOfGroup,
                          showStatus: isLastMessageOfGroup,
                          partnerNickname: partnerNickname,
                          partnerProfileImage: partnerProfileImage,
                          highlighted: message.id != null &&
                              _highlightedMessageId == message.id,
                          onRetry: (
                            message,
                          ) {
                            _retryMessage(
                              message,
                              realtimeController,
                            );
                          },
                          onDelete: isMine && !message.deleted
                              ? () {
                                  _confirmDeleteMessage(
                                    message,
                                  );
                                }
                              : null,
                          onSecondaryTapDown: message.deleted
                              ? null
                              : (
                                  details,
                                ) {
                                  _showMessageContextMenu(
                                    position: details.globalPosition,
                                    message: message,
                                    isMine: isMine,
                                  );
                                },
                          onReplyTap: (
                            messageId,
                          ) {
                            _goToMessage(
                              messageId,
                            );
                          },
                          onImageOpen: (
                            imageMessages,
                            initialIndex,
                          ) {
                            final imageUrls = imageMessages
                                .map(
                                    (message) => MediaUrlUtils.resolveChatImage(
                                          message.content,
                                        ))
                                .toList();

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatImageViewerPage(
                                  imageUrls: imageUrls,
                                  initialIndex: initialIndex,
                                ),
                              ),
                            );
                          },
                          onImageSave: (imageMessage) {
                            _saveChatImage(
                              imageMessage,
                            );
                          },
                          onImageReply: (imageMessage) {
                            setState(() {
                              _editingMessage = null;
                              _replyingToMessage = imageMessage;
                            });
                          },
                          onImageDelete: isMine
                              ? (imageMessage) {
                                  _confirmDeleteMessage(
                                    imageMessage,
                                  );
                                }
                              : null,
                          onImageRetry: isMine
                              ? (imageMessage) {
                                  _retryMessage(
                                    imageMessage,
                                    realtimeController,
                                  );
                                }
                              : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 180,
            ),
            child: _showScrollToBottomButton && !_showNewMessageBanner
                ? Align(
                    key: const ValueKey(
                      'scrollBottomButton',
                    ),
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 16,
                        bottom: 4,
                      ),
                      child: Material(
                        elevation: 3,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: '맨 아래로 이동',
                          onPressed: () {
                            setState(() {
                              _showScrollToBottomButton = false;

                              _showNewMessageBanner = false;

                              _latestIncomingContent = null;

                              _newMessageCount = 0;
                            });

                            _scrollToBottom();
                          },
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey(
                      'noScrollBottomButton',
                    ),
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(
              milliseconds: 200,
            ),
            child: realtimeState.partnerTyping
                ? Padding(
                    key: const ValueKey(
                      'typing',
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$partnerNickname님이 입력 중...',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall,
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey(
                      'notTyping',
                    ),
                  ),
          ),
          if (_showNewMessageBanner && _latestIncomingContent != null)
            _NewMessageBanner(
              content: _latestIncomingContent!,
              count: _newMessageCount,
              onTap: () {
                setState(() {
                  _showNewMessageBanner = false;
                  _latestIncomingContent = null;
                  _newMessageCount = 0;
                });
                _scrollToBottom();
              },
            ),
          if (_showIncomingPreview && _incomingPreviewContent != null)
            _IncomingMessagePreview(
              content: _incomingPreviewContent!,
              onTap: () {
                _incomingPreviewTimer?.cancel();

                setState(() {
                  _showIncomingPreview = false;
                  _incomingPreviewContent = null;
                });

                _scrollToBottom();
              },
            ),
          if (_replyingToMessage != null)
            _ReplyPreview(
              message: _replyingToMessage!,
              onClose: () {
                setState(() {
                  _replyingToMessage = null;
                });
              },
            ),
          if (_editingMessage != null)
            _EditMessagePreview(
              message: _editingMessage!,
              onClose: () {
                setState(() {
                  _editingMessage = null;
                  _messageController.clear();
                });
              },
            ),
          if (_pendingImages.isNotEmpty)
            _ChatImagePreviewList(
              images: _pendingImages,
              uploading: _uploadingImages,
              onRemove: (index) {
                if (_uploadingImages) {
                  return;
                }

                if (index < 0 || index >= _pendingImages.length) {
                  return;
                }

                setState(() {
                  _pendingImages.removeAt(
                    index,
                  );

                  /*
     * 보내려던 이미지가 하나도 남지 않았다면
     * 이미지에 걸려 있던 reply도 해제
     */
                  if (_pendingImages.isEmpty) {
                    _replyingToMessage = null;
                    _imageUploadProgress = 0;
                  }
                });
              },
              onEdit: (index) {
                _editPendingImage(
                  index,
                );
              },
              onRetry: (index) {
                _retryPendingImageUpload(
                  index,
                  realtimeController,
                );
              },
              onReorder: (oldIndex, newIndex) {
                _reorderPendingImages(oldIndex, newIndex);
              },
            ),
          if (_uploadingImages)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _imageUploadProgress,
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(_imageUploadProgress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          _MessageInput(
            controller: _messageController,
            enabled: realtimeState.connected,
            uploadingImage: _uploadingImages,
            onImage: () {
              _pickChatImages();
            },
            onChanged: (_) {
              realtimeController.sendTyping();
            },
            onSend: () {
              if (_pendingImages.isNotEmpty) {
                _uploadPendingImages(
                  realtimeController,
                );

                return;
              }

              _sendMessage(
                realtimeController,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<String> _uploadSinglePendingImage(
    PendingChatImage image,
  ) async {
    final uploaded = await ref
        .read(
          chatApiProvider,
        )
        .uploadChatImages(
          coupleId: widget.coupleId,
          images: [
            image,
          ],
          onProgress: (
            sent,
            total,
          ) {},
        );

    if (uploaded.isEmpty) {
      throw Exception(
        '이미지 업로드 결과가 없습니다.',
      );
    }

    return uploaded.first.url;
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isFirstOfGroup;
  final bool showProfile;
  final bool showStatus;
  final String partnerNickname;
  final String? partnerProfileImage;
  final VoidCallback? onDelete;
  final bool highlighted;
  final void Function(TapDownDetails detals)? onSecondaryTapDown;
  final void Function(ChatMessage message)? onRetry;
  final ValueChanged<int> onReplyTap;
  final List<ChatMessage> mediaGroup;
  final void Function(List<ChatMessage> messages, int index)? onImageOpen;
  final void Function(ChatMessage message)? onImageSave;
  final void Function(ChatMessage message)? onImageReply;
  final void Function(ChatMessage message)? onImageDelete;
  final void Function(ChatMessage message)? onImageRetry;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isFirstOfGroup,
    required this.showProfile,
    required this.showStatus,
    required this.partnerNickname,
    required this.partnerProfileImage,
    required this.onDelete,
    required this.highlighted,
    required this.onSecondaryTapDown,
    this.onRetry,
    required this.onReplyTap,
    required this.mediaGroup,
    this.onImageOpen,
    this.onImageSave,
    this.onImageReply,
    this.onImageDelete,
    this.onImageRetry,
  });

  @override
  Widget build(BuildContext context) {
    final time = '${message.sentAt.hour.toString().padLeft(2, '0')}:'
        '${message.sentAt.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onLongPress: isMine && !message.deleted ? onDelete : null,
      onSecondaryTapDown: message.deleted ? null : onSecondaryTapDown,
      child: Padding(
        padding: EdgeInsets.only(
          top: isFirstOfGroup ? 10 : 2,
          bottom: showStatus ? 6 : 2,
        ),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              if (showProfile)
                _ProfileAvatar(
                  profileImage: partnerProfileImage,
                  nickname: partnerNickname,
                )
              else
                const SizedBox(
                  width: 44,
                ),
              const SizedBox(
                width: 8,
              ),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine && showProfile)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: 4,
                      ),
                      child: Text(
                        partnerNickname,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium,
                      ),
                    ),
                  if (isMine &&
                      message.type == ChatMessageType.text &&
                      message.sendStatus == ChatMessageSendStatus.sending)
                    const Padding(
                      padding: EdgeInsets.only(
                        right: 4,
                      ),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                        ),
                      ),
                    ),
                  if (isMine &&
                      message.type == ChatMessageType.text &&
                      message.sendStatus == ChatMessageSendStatus.failed)
                    IconButton(
                      tooltip: '재전송',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                      ),
                      onPressed: () {
                        onRetry?.call(
                          message,
                        );
                      },
                    ),
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 320,
                    ),
                    padding: message.deleted
                        ? const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          )
                        : message.type == ChatMessageType.image
                            ? const EdgeInsets.all(
                                4,
                              )
                            : const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                    decoration: BoxDecoration(
                      color: message.deleted
                          ? Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                          : isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        16,
                      ),
                      border: highlighted
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyToMessageId != null) ...[
                          _ReplyQuote(
                            senderNickname: message.replyToSenderNickname,
                            type: message.replyToType,
                            content: message.replyToContent,
                            onTap: () {
                              onReplyTap(
                                message.replyToMessageId!,
                              );
                            },
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                        ],
                        if (message.deleted)
                          Text(
                            '삭제된 메시지입니다.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                          )
                        else if (message.type == ChatMessageType.image)
                          mediaGroup.length > 1
                              ? _ChatImageGrid(
                                  messages: mediaGroup,
                                  onOpen: onImageOpen,
                                  onSave: onImageSave,
                                  onReply: onImageReply,
                                  onDelete: onImageDelete,
                                  onRetry: onImageRetry,
                                )
                              : _ChatImage(
                                  message: message,
                                  onRetry: onImageRetry == null
                                      ? null
                                      : () {
                                          onImageRetry!(
                                            message,
                                          );
                                        },
                                )
                        else
                          Text(
                            message.content,
                          ),
                      ],
                    ),
                  ),
                  if (showStatus) ...[
                    const SizedBox(
                      height: 3,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMine && message.readAt != null)
                          Text(
                            '읽음  ',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall,
                          ),
                        Text(
                          message.edited ? '$time · 수정됨' : time,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatImage extends StatelessWidget {
  final ChatMessage message;

  final VoidCallback? onRetry;

  const _ChatImage({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final resolvedUrl = MediaUrlUtils.resolveChatImage(
      message.content,
    );

    debugPrint(
      '[CHAT IMAGE] '
      'raw=${message.content}',
    );

    debugPrint(
      '[CHAT IMAGE] '
      'resolved=$resolvedUrl',
    );

    final isSending = message.sendStatus == ChatMessageSendStatus.sending;

    final isFailed = message.sendStatus == ChatMessageSendStatus.failed;

    return SizedBox(
      width: 240,
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(
            onTap: isSending || isFailed
                ? null
                : () {
                    Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) => ChatImageViewerPage.single(
                          imageUrl: resolvedUrl,
                        ),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(
              12,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                12,
              ),
              child: AuthenticatedNetworkImage(
                url: resolvedUrl,
                fit: BoxFit.cover,
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  debugPrint(
                    '[CHAT IMAGE ERROR] '
                    'url=$resolvedUrl '
                    'error=$error',
                  );

                  return const Center(
                    child: Text(
                      '이미지를 불러올 수 없습니다.',
                    ),
                  );
                },
              ),
            ),
          ),
          if (isSending)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          if (isFailed)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  const Text(
                    '전송 실패',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  IconButton(
                    tooltip: '재전송',
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatImageGrid extends StatelessWidget {
  final List<ChatMessage> messages;

  final void Function(
    List<ChatMessage> messages,
    int index,
  )? onOpen;

  final void Function(
    ChatMessage message,
  )? onSave;

  final void Function(
    ChatMessage message,
  )? onReply;

  final void Function(
    ChatMessage message,
  )? onDelete;

  final void Function(
    ChatMessage message,
  )? onRetry;

  const _ChatImageGrid({
    required this.messages,
    this.onOpen,
    this.onSave,
    this.onReply,
    this.onDelete,
    this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    /*
     * 너무 많은 사진이 있어도
     * 버블에서는 최대 4장까지만 직접 표시
     */
    final visible = messages.take(4).toList();

    final remaining = messages.length - 4;

    if (messages.length == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildImage(
            context,
            visible[0],
            0,
            118,
            180,
          ),
          const SizedBox(
            width: 4,
          ),
          _buildImage(
            context,
            visible[1],
            1,
            118,
            180,
          ),
        ],
      );
    }

    if (messages.length == 3) {
      return SizedBox(
        width: 240,
        height: 240,
        child: Row(
          children: [
            Expanded(
              child: _buildImage(
                context,
                visible[0],
                0,
                double.infinity,
                double.infinity,
              ),
            ),
            const SizedBox(
              width: 4,
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _buildImage(
                      context,
                      visible[1],
                      1,
                      double.infinity,
                      double.infinity,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Expanded(
                    child: _buildImage(
                      context,
                      visible[2],
                      2,
                      double.infinity,
                      double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    /*
     * 4장 이상
     */
    return SizedBox(
      width: 240,
      height: 240,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final showMore = index == 3 && remaining > 0;

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(
                context,
                visible[index],
                index,
                double.infinity,
                double.infinity,
              ),
              if (showMore)
                Container(
                  alignment: Alignment.center,
                  color: Colors.black45,
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    ChatMessage message,
    int index,
    double width,
    double height,
  ) {
    final url = MediaUrlUtils.resolveChatImage(
      message.content,
    );

    final isSending = message.sendStatus == ChatMessageSendStatus.sending;

    final isFailed = message.sendStatus == ChatMessageSendStatus.failed;

    /*
   * 118, 180 같은 실제 크기면 적용.
   *
   * double.infinity인 경우에는
   * Expanded/GridView가 크기를 결정하도록 null 사용.
   */
    final resolvedWidth = width.isFinite ? width : null;

    final resolvedHeight = height.isFinite ? height : null;

    return SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
      child: GestureDetector(
        /*
       * 전송 중에는 메뉴 비활성화
       */
        onLongPressStart: isSending
            ? null
            : (details) {
                _showImageMenu(
                  context: context,
                  position: details.globalPosition,
                  message: message,
                );
              },

        /*
       * Web / Desktop 우클릭
       */
        onSecondaryTapDown: isSending
            ? null
            : (details) {
                _showImageMenu(
                  context: context,
                  position: details.globalPosition,
                  message: message,
                );
              },
        child: Stack(
          fit: StackFit.expand,
          children: [
            /*
           * 실제 이미지
           */
            InkWell(
              onTap: isSending || isFailed
                  ? null
                  : () {
                      onOpen?.call(
                        messages,
                        index,
                      );
                    },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  8,
                ),
                child: AuthenticatedNetworkImage(
                  url: url,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    debugPrint(
                      '[CHAT IMAGE ERROR] '
                      'url=$url '
                      'error=$error',
                    );

                    return Container(
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                      ),
                    );
                  },
                ),
              ),
            ),

            /*
           * sending 상태
           */
            if (isSending)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(
                    8,
                  ),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),

            /*
           * failed 상태
           */
            if (isFailed)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(
                    8,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    const Text(
                      '전송 실패',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                        onTap: onRetry == null
                            ? null
                            : () {
                                onRetry?.call(
                                  message,
                                );
                              },
                        child: const Padding(
                          padding: EdgeInsets.all(
                            6,
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageMenu({
    required BuildContext context,
    required Offset position,
    required ChatMessage message,
  }) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'open',
          child: Row(
            children: [
              Icon(
                Icons.open_in_full,
                size: 20,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                '이미지 열기',
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'save',
          child: Row(
            children: [
              Icon(
                Icons.download_outlined,
                size: 20,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                '이미지 저장',
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(
                Icons.reply,
                size: 20,
              ),
              SizedBox(
                width: 10,
              ),
              Text(
                '답장',
              ),
            ],
          ),
        ),
        if (onDelete != null)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(
                  '삭제',
                ),
              ],
            ),
          ),
      ],
    );

    if (selected == null) {
      return;
    }

    switch (selected) {
      case 'open':
        final index = messages.indexWhere(
          (item) => item.id == message.id,
        );

        if (index >= 0) {
          onOpen?.call(
            messages,
            index,
          );
        }
        break;

      case 'save':
        onSave?.call(
          message,
        );
        break;

      case 'reply':
        onReply?.call(
          message,
        );
        break;

      case 'delete':
        onDelete?.call(
          message,
        );
        break;
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? profileImage;
  final String nickname;

  const _ProfileAvatar({
    required this.profileImage,
    required this.nickname,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasImage = profileImage != null && profileImage!.trim().isNotEmpty;

    if (!hasImage) {
      return CircleAvatar(
        radius: 18,
        child: Text(
          nickname.isNotEmpty ? nickname[0] : '?',
        ),
      );
    }

    final resolvedUrl = MediaUrlUtils.resolveChatImage(
      profileImage!,
    );

    debugPrint(
      'PROFILE IMAGE URL='
      '$resolvedUrl',
    );

    return ClipOval(
      child: Image.network(
        resolvedUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          debugPrint(
            'PROFILE IMAGE ERROR: '
            '$error',
          );

          return CircleAvatar(
            radius: 22,
            child: Text(
              nickname.isNotEmpty ? nickname[0] : '?',
            ),
          );
        },
      ),
    );
  }
}

class _ChatSearchSheet extends ConsumerStatefulWidget {
  final int coupleId;
  final int myUserId;
  final int partnerId;
  final String partnerNickname;
  final ValueChanged<int> onMessageSelected;

  const _ChatSearchSheet({
    required this.coupleId,
    required this.myUserId,
    required this.partnerId,
    required this.partnerNickname,
    required this.onMessageSelected,
  });

  @override
  ConsumerState<_ChatSearchSheet> createState() => _ChatSearchSheetState();
}

class _ChatSearchSheetState extends ConsumerState<_ChatSearchSheet> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;

  List<ChatSearchResult> _results = [];

  bool _loading = false;
  bool _loadingMore = false;
  bool _searched = false;
  bool _useNori = true;

  bool _hasMore = false;

  DateTime? _nextSentAt;
  int? _nextMessageId;

  int? _senderId;
  ChatMessageType? _messageType;

  DateTime? _fromDate;
  DateTime? _toDate;

  final ScrollController _searchScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _searchScrollController.addListener(
      _onSearchScroll,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _searchScrollController.removeListener(
      _onSearchScroll,
    );

    _searchScrollController.dispose();
    _controller.dispose();

    super.dispose();
  }

  void _onSearchChanged(
    String value,
  ) {
    _debounce?.cancel();

    final keyword = value.trim();

    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
        _loadingMore = false;

        _hasMore = false;
        _nextSentAt = null;
        _nextMessageId = null;
      });

      return;
    }

    _debounce = Timer(
      const Duration(
        milliseconds: 400,
      ),
      () {
        _search();
      },
    );
  }

  void _onSearchScroll() {
    if (!_searchScrollController.hasClients) {
      return;
    }

    final position = _searchScrollController.position;

    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMoreSearch();
    }
  }

  Future<void> _loadMoreSearch() async {
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _nextSentAt == null ||
        _nextMessageId == null) {
      return;
    }

    final keyword = _controller.text.trim();

    final hasFilter = _senderId != null ||
        _messageType != null ||
        _fromDate != null ||
        _toDate != null;

    if (keyword.isEmpty && !hasFilter) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final page = await ref.read(chatApiProvider).searchMessages(
            coupleId: widget.coupleId,
            keyword: keyword,
            useNori: _useNori,
            size: 20,
            beforeSentAt: _nextSentAt,
            beforeMessageId: _nextMessageId,
            senderId: _senderId,
            type: _messageType,
            fromDate: _fromDate,
            toDate: _toDate,
          );

      if (!mounted) {
        return;
      }

      /*
     * 혹시라도 중복이 내려오더라도
     * messageId 기준으로 제거
     */
      final existingIds = _results
          .map(
            (e) => e.messageId,
          )
          .toSet();

      final newMessages = page.messages
          .where(
            (message) => !existingIds.contains(
              message.messageId,
            ),
          )
          .toList();

      setState(() {
        _results.addAll(
          newMessages,
        );

        _hasMore = page.hasMore;

        _nextSentAt = page.nextSentAt;

        _nextMessageId = page.nextMessageId;
      });
      _checkAndLoadMoreIfNeeded();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '검색 결과를 더 불러오지 못했습니다: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();

    final hasFilter = _senderId != null ||
        _messageType != null ||
        _fromDate != null ||
        _toDate != null;

    if (keyword.isEmpty && !hasFilter) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
        _loadingMore = false;

        _hasMore = false;
        _nextSentAt = null;
        _nextMessageId = null;
      });

      return;
    }

    setState(() {
      _loading = true;
      _searched = true;

      _results = [];

      _hasMore = false;
      _nextSentAt = null;
      _nextMessageId = null;
    });

    try {
      final page = await ref.read(chatApiProvider).searchMessages(
            coupleId: widget.coupleId,
            keyword: keyword,
            useNori: _useNori,
            size: 20,
            senderId: _senderId,
            type: _messageType,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _results = page.messages;

        _hasMore = page.hasMore;

        _nextSentAt = page.nextSentAt;

        _nextMessageId = page.nextMessageId;
      });

      _checkAndLoadMoreIfNeeded();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '채팅 검색 실패: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _checkAndLoadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted || !_searchScrollController.hasClients) {
          return;
        }

        final position = _searchScrollController.position;

        /*
       * 검색 결과가 화면보다 짧아서
       * 스크롤 자체가 생기지 않은 경우
       */
        if (position.maxScrollExtent <= 0 &&
            _hasMore &&
            !_loading &&
            !_loadingMore) {
          _loadMoreSearch();
        }
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(
            16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _search();
                  },
                  decoration: const InputDecoration(
                    hintText: '채팅 내용을 검색하세요',
                    prefixIcon: Icon(
                      Icons.search,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              IconButton.filled(
                onPressed: _loading
                    ? null
                    : () {
                        _debounce?.cancel();
                        _search();
                      },
                icon: const Icon(
                  Icons.search,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                const Icon(
                  Icons.translate,
                  size: 18,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '한국어 검색 강화',
                      ),
                      Text(
                        _useNori ? '형태소 분석 검색 사용 중' : '일반 검색 사용 중',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _useNori,
                  onChanged: (
                    value,
                  ) {
                    setState(() {
                      _useNori = value;
                    });

                    _debounce?.cancel();

                    if (_controller.text.trim().isNotEmpty) {
                      _search();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _senderId == null,
                onSelected: (_) {
                  setState(() {
                    _senderId = null;
                  });

                  _search();
                },
              ),
              ChoiceChip(
                label: const Text('내 메시지'),
                selected: _senderId == widget.myUserId,
                onSelected: (_) {
                  setState(() {
                    _senderId = widget.myUserId;
                  });

                  _search();
                },
              ),
              ChoiceChip(
                label: Text(
                  widget.partnerNickname,
                ),
                selected: _senderId == widget.partnerId,
                onSelected: (_) {
                  setState(() {
                    _senderId = widget.partnerId;
                  });

                  _search();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체 타입'),
                selected: _messageType == null,
                onSelected: (_) {
                  setState(() {
                    _messageType = null;
                  });

                  _search();
                },
              ),
              ChoiceChip(
                label: const Text('텍스트'),
                selected: _messageType == ChatMessageType.text,
                onSelected: (_) {
                  setState(() {
                    _messageType = ChatMessageType.text;
                  });

                  _search();
                },
              ),
              ChoiceChip(
                label: const Text('사진'),
                selected: _messageType == ChatMessageType.image,
                onSelected: (_) {
                  setState(() {
                    _messageType = ChatMessageType.image;
                  });

                  _search();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _fromDate == null
                        ? '시작일'
                        : '${_fromDate!.year}.'
                            '${_fromDate!.month}.'
                            '${_fromDate!.day}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fromDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );

                    if (picked == null) {
                      return;
                    }

                    setState(() {
                      _fromDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                      );
                    });

                    _search();
                  },
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.event_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _toDate == null
                        ? '종료일'
                        : '${_toDate!.year}.'
                            '${_toDate!.month}.'
                            '${_toDate!.day}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _toDate ?? DateTime.now(),
                      firstDate: _fromDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );

                    if (picked == null) {
                      return;
                    }

                    setState(() {
                      /*
               * 종료일 하루 전체 포함
               */
                      _toDate = DateTime(picked.year, picked.month, picked.day);
                    });

                    _search();
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(
                Icons.restart_alt,
              ),
              label: const Text(
                '필터 초기화',
              ),
              onPressed: () {
                setState(() {
                  _senderId = null;
                  _messageType = null;
                  _fromDate = null;
                  _toDate = null;
                  _useNori = true;
                });

                if (_controller.text.trim().isNotEmpty) {
                  _search();
                } else {
                  setState(() {
                    _results = [];
                    _searched = false;
                    _hasMore = false;
                    _nextSentAt = null;
                    _nextMessageId = null;
                  });
                }
              },
            ),
          ),
        ),
        if (_searched && !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '검색 결과 ${_results.length}개',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall,
              ),
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _buildResult(),
        ),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        if (_searched &&
            !_loading &&
            !_loadingMore &&
            _results.isNotEmpty &&
            !_hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Text(
              '검색 결과의 끝입니다.',
            ),
          ),
      ],
    );
  }

  Widget _buildResult() {
    if (!_searched) {
      return const Center(
        child: Text(
          '검색어를 입력하거나 필터를 선택하세요.',
        ),
      );
    }

    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '검색 결과가 없습니다.',
        ),
      );
    }

    return ListView.separated(
      controller: _searchScrollController,
      itemCount: _results.length,
      separatorBuilder: (
        context,
        index,
      ) {
        return const Divider(
          height: 1,
        );
      },
      itemBuilder: (
        context,
        index,
      ) {
        final result = _results[index];

        return ListTile(
          onTap: () {
            widget.onMessageSelected(
              result.messageId,
            );
          },
          leading: CircleAvatar(
            child: Text(
              result.senderNickname.isNotEmpty ? result.senderNickname[0] : '?',
            ),
          ),
          title: Text(
            result.senderNickname,
          ),
          subtitle: _HighlightedSearchText(
            text: result.content,
            keyword: _controller.text,
          ),
          trailing: Text(
            _formatSearchTime(
              result.sentAt,
            ),
            style: Theme.of(
              context,
            ).textTheme.labelSmall,
          ),
        );
      },
    );
  }
}

String _formatSearchTime(
  DateTime dateTime,
) {
  final now = DateTime.now();

  if (_isSameDay(
    dateTime,
    now,
  )) {
    return '${dateTime.hour.toString().padLeft(2, '0')}시'
        '${dateTime.minute.toString().padLeft(2, '0')}분';
  }

  return '${dateTime.year}년 '
      '${dateTime.month}월 '
      '${dateTime.day}일';
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final bool uploadingImage;

  const _MessageInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    required this.onImage,
    required this.uploadingImage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '이미지 보내기',
              onPressed: enabled && !uploadingImage ? onImage : null,
              icon: uploadingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.image_outlined,
                    ),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (
                  node,
                  event,
                ) {
                  if (event is! KeyDownEvent) {
                    return KeyEventResult.ignored;
                  }

                  final isEnter =
                      event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter;

                  if (!isEnter) {
                    return KeyEventResult.ignored;
                  }

                  final isShiftPressed =
                      HardwareKeyboard.instance.isShiftPressed;

                  /*
                   * Shift + Enter
                   * → 기본 TextField 줄바꿈 허용
                   */
                  if (isShiftPressed) {
                    return KeyEventResult.ignored;
                  }

                  /*
                   * Enter
                   * → 줄바꿈하지 않고 전송
                   */
                  if (enabled) {
                    onSend();
                  }

                  return KeyEventResult.handled;
                },
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: onChanged,

                  /*
                   * onSubmitted는 제거
                   */

                  decoration: const InputDecoration(
                    hintText: '메시지를 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            IconButton.filled(
              onPressed: enabled && !uploadingImage ? onSend : null,
              icon: uploadingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMessageBanner extends StatelessWidget {
  final String content;
  final int count;
  final VoidCallback onTap;

  const _NewMessageBanner({
    required this.content,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        8,
      ),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            14,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1 ? '새 메시지' : '새 메시지 $count개',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium,
                      ),
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(
  DateTime a,
  DateTime b,
) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isSameMessageGroup(
  ChatMessage a,
  ChatMessage b,
) {
  /*
   * 보낸 사람이 다르면
   * 다른 그룹
   */
  if (a.senderId != b.senderId) {
    return false;
  }

  /*
   * 날짜가 다르면
   * 다른 그룹
   */
  if (!_isSameDay(
    a.sentAt,
    b.sentAt,
  )) {
    return false;
  }

  /*
   * 두 메시지 간 시간 차이가
   * 5분 이하일 때만 같은 그룹
   */
  final difference = b.sentAt.difference(
    a.sentAt,
  );

  return difference.inMinutes <= 3;
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({
    required this.date,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final today = DateTime.now();

    final yesterday = today.subtract(
      const Duration(days: 1),
    );

    String text;

    if (_isSameDay(
      date,
      today,
    )) {
      text = '오늘';
    } else if (_isSameDay(
      date,
      yesterday,
    )) {
      text = '어제';
    } else {
      text = '${date.year}년 '
          '${date.month}월 '
          '${date.day}일';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(
              20,
            ),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  final int count;

  const _UnreadDivider({
    required this.count,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.45,
                  ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            count > 1 ? '여기부터 읽지 않은 메시지 $count개' : '여기부터 읽지 않은 메시지',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: 0.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAnnouncementBar extends StatefulWidget {
  final ChatAnnouncement announcement;
  final VoidCallback onGoToMessage;
  final VoidCallback onRemove;

  const _ChatAnnouncementBar({
    required this.announcement,
    required this.onGoToMessage,
    required this.onRemove,
  });

  @override
  State<_ChatAnnouncementBar> createState() => _ChatAnnouncementBarState();
}

class _ChatAnnouncementBarState extends State<_ChatAnnouncementBar> {
  bool _expanded = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final announcement = widget.announcement;

    return Material(
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: AnimatedSize(
          duration: const Duration(
            milliseconds: 200,
          ),
          curve: Curves.easeInOut,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      size: 20,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        announcement.content,
                        maxLines: _expanded ? null : 1,
                        overflow: _expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(
                    height: 12,
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    '원본 메시지',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium,
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '${announcement.messageSenderNickname} · '
                    '${_formatAnnouncementTime(announcement.messageSentAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    '공지 등록',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium,
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '${announcement.createdByNickname} · '
                    '${_formatAnnouncementTime(announcement.createdAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onRemove,
                        icon: const Icon(
                          Icons.campaign_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          '공지 해제',
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      TextButton.icon(
                        onPressed: widget.onGoToMessage,
                        icon: const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 18,
                        ),
                        label: const Text(
                          '원본 메시지로 이동',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatAnnouncementTime(
  DateTime dateTime,
) {
  final now = DateTime.now();

  if (_isSameDay(
    dateTime,
    now,
  )) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  return '${dateTime.year}.'
      '${dateTime.month.toString().padLeft(2, '0')}.'
      '${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}

class _ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onClose;

  const _ReplyPreview({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isImage = message.type == ChatMessageType.image && !message.deleted;

    final previewText = message.deleted
        ? '삭제된 메시지입니다.'
        : isImage
            ? '사진'
            : message.content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        8,
        8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.reply,
            size: 20,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${message.senderNickname ?? ''}에게 답장',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (isImage) ...[
            const SizedBox(
              width: 8,
            ),
            ClipRRect(
                borderRadius: BorderRadius.circular(
                  6,
                ),
                child: AuthenticatedNetworkImage(
                  url: MediaUrlUtils.resolveChatImage(
                    message.content,
                  ),
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                )),
          ],
          IconButton(
            tooltip: '답장 취소',
            onPressed: onClose,
            icon: const Icon(
              Icons.close,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final String? senderNickname;
  final ChatMessageType? type;
  final String? content;
  final VoidCallback onTap;

  const _ReplyQuote({
    required this.senderNickname,
    required this.type,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isDeleted =
        content == null || content!.isEmpty || content == '삭제된 메시지입니다.';

    final isImage = type == ChatMessageType.image && !isDeleted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        8,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(
                alpha: 0.55,
              ),
          borderRadius: BorderRadius.circular(
            8,
          ),
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderNickname != null && senderNickname!.isNotEmpty)
                    Text(
                      senderNickname!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  const SizedBox(
                    height: 3,
                  ),
                  if (isDeleted)
                    Text(
                      '삭제된 메시지입니다.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    )
                  else if (isImage)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 16,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          '사진',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    )
                  else
                    Text(
                      content ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (isImage) ...[
              const SizedBox(
                width: 8,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  6,
                ),
                child: AuthenticatedNetworkImage(
                  url: MediaUrlUtils.resolveChatImage(
                    content!,
                  ),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditMessagePreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onClose;

  const _EditMessagePreview({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        8,
        8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.edit_outlined,
            size: 20,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '메시지 수정',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '수정 취소',
            onPressed: onClose,
            icon: const Icon(
              Icons.close,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingMessagePreview extends StatelessWidget {
  final String content;
  final VoidCallback onTap;

  const _IncomingMessagePreview({
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        4,
        12,
        4,
      ),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(
          10,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            10,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedSearchText extends StatelessWidget {
  final String text;
  final String keyword;
  final int maxLines;

  const _HighlightedSearchText({
    required this.text,
    required this.keyword,
    this.maxLines = 2,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final trimmedKeyword = keyword.trim();

    if (trimmedKeyword.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();

    final lowerKeyword = trimmedKeyword.toLowerCase();

    final spans = <TextSpan>[];

    int start = 0;

    while (true) {
      final index = lowerText.indexOf(
        lowerKeyword,
        start,
      );

      if (index < 0) {
        spans.add(
          TextSpan(
            text: text.substring(
              start,
            ),
          ),
        );

        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(
              start,
              index,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(
            index,
            index + trimmedKeyword.length,
          ),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + trimmedKeyword.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style,
        children: spans,
      ),
    );
  }
}

class _ChatImagePreviewList extends StatelessWidget {
  final List<PendingChatImage> images;
  final bool uploading;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRetry;
  final void Function(
    int oldIndex,
    int newIndex,
  ) onReorder;

  const _ChatImagePreviewList({
    required this.images,
    required this.uploading,
    required this.onRemove,
    required this.onEdit,
    required this.onRetry,
    required this.onReorder,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height: 108,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        itemCount: images.length,
        onReorder: uploading
            ? (
                _,
                __,
              ) {}
            : onReorder,
        proxyDecorator: (
          child,
          index,
          animation,
        ) {
          return Material(
            elevation: 6,
            color: Colors.transparent,
            child: child,
          );
        },
        itemBuilder: (
          context,
          index,
        ) {
          final image = images[index];

          final bytes = image.compressedBytes ?? image.originalBytes;

          final canReorder = !uploading &&
              image.status != ChatImageUploadStatus.uploading &&
              image.status != ChatImageUploadStatus.compressing;

          return Padding(
            key: ValueKey(
              image.clientMessageId ?? '${image.name}-$index',
            ),
            padding: const EdgeInsets.only(
              right: 8,
            ),
            child: SizedBox(
              width: 84,
              height: 92,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: uploading ||
                              image.status ==
                                  ChatImageUploadStatus.compressing ||
                              image.status == ChatImageUploadStatus.uploading ||
                              image.status == ChatImageUploadStatus.failed
                          ? null
                          : () {
                              onEdit(
                                index,
                              );
                            },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          10,
                        ),
                        child: Image.memory(
                          bytes,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  /*
                 * 압축 중
                 */
                  if (image.status == ChatImageUploadStatus.compressing)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  /*
                 * HTTP 업로드 중
                 */
                  if (image.status == ChatImageUploadStatus.uploading)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  /*
                 * HTTP 업로드 실패
                 */
                  if (image.status == ChatImageUploadStatus.failed)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            const Text(
                              '업로드 실패',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),

                            /*
                           * 재업로드 / 취소
                           */
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    onRetry(
                                      index,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(
                                      4,
                                    ),
                                    child: Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                InkWell(
                                  onTap: () {
                                    onRemove(
                                      index,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(
                                      4,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  /*
                 * 일반 상태의 편집 버튼
                 */
                  if (!uploading && image.status == ChatImageUploadStatus.ready)
                    Positioned(
                      bottom: 11,
                      right: 3,
                      child: GestureDetector(
                        onTap: () {
                          onEdit(
                            index,
                          );
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          padding: const EdgeInsets.all(
                            4,
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  /*
                 * 일반 상태 삭제
                 */
                  if (!uploading &&
                      image.status != ChatImageUploadStatus.failed &&
                      image.status != ChatImageUploadStatus.uploading)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: () {
                          onRemove(
                            index,
                          );
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          padding: const EdgeInsets.all(
                            3,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  /*
                 * 드래그 핸들
                 *
                 * PC에서는 이 아이콘을 잡고
                 * 좌우로 이동.
                 */
                  if (canReorder)
                    Positioned(
                      left: 3,
                      bottom: 10,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          padding: const EdgeInsets.all(
                            4,
                          ),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          child: const Icon(
                            Icons.drag_indicator,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
