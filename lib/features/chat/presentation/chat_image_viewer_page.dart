import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/utils/media_url_utils.dart';
import '../../../core/widgets/authenticated_network_image.dart';

class ChatImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ChatImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  factory ChatImageViewerPage.single({
    required String imageUrl,
  }) {
    return ChatImageViewerPage(
      imageUrls: [imageUrl],
      initialIndex: 0,
    );
  }

  @override
  State<ChatImageViewerPage> createState() => _ChatImageViewerPageState();
}

class _ChatImageViewerPageState extends State<ChatImageViewerPage> {
  late final PageController _pageController;

  late int _currentIndex;

  bool _pageSwipeEnabled = true;

  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();

    final safeIndex = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex.clamp(
            0,
            widget.imageUrls.length - 1,
          );

    _currentIndex = safeIndex;

    _pageController = PageController(
      initialPage: safeIndex,
    );
  }

  TransformationController _controllerFor(
    int index,
  ) {
    return _transformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();

    for (final controller in _transformControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (widget.imageUrls.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            '이미지가 없습니다.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.imageUrls.length > 1
            ? Text(
                '${_currentIndex + 1} / '
                '${widget.imageUrls.length}',
              )
            : null,
      ),
      body: ScrollConfiguration(
        behavior: const _MouseDragScrollBehavior(),
        child: PageView.builder(
          controller: _pageController,
          physics: _pageSwipeEnabled
              ? const PageScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            final previousController = _transformControllers[_currentIndex];

            previousController?.value = Matrix4.identity();

            setState(() {
              _currentIndex = index;
              _pageSwipeEnabled = true;
            });
          },
          itemBuilder: (
            context,
            index,
          ) {
            final imageUrl = MediaUrlUtils.resolveChatImage(
              widget.imageUrls[index],
            );

            final transformController = _controllerFor(index);

            return Center(
              child: InteractiveViewer(
                transformationController: transformController,
                minScale: 1,
                maxScale: 5,

                /*
           * 확대 상태에서만 이미지 자체 이동.
           * 1배에서는 PageView가 마우스 drag를 받음.
           */
                panEnabled: !_pageSwipeEnabled,
                scaleEnabled: true,
                onInteractionUpdate: (
                  details,
                ) {
                  final scale = transformController.value.getMaxScaleOnAxis();

                  final shouldEnable = scale <= 1.01;

                  if (_pageSwipeEnabled != shouldEnable) {
                    setState(() {
                      _pageSwipeEnabled = shouldEnable;
                    });
                  }
                },
                onInteractionEnd: (
                  details,
                ) {
                  final scale = transformController.value.getMaxScaleOnAxis();

                  if (scale <= 1.01 && !_pageSwipeEnabled) {
                    setState(() {
                      _pageSwipeEnabled = true;
                    });
                  }
                },
                child: AuthenticatedNetworkImage(
                  url: imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (
                    context,
                    child,
                    progress,
                  ) {
                    if (progress == null) {
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
                    return const Center(
                      child: Text(
                        '이미지를 불러올 수 없습니다.',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}
