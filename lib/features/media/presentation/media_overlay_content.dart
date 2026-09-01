import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MediaOverlayContent extends ConsumerWidget {
  const MediaOverlayContent({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    /*
     * 실제 tiles 연결은
     * MediaRoom 상태 연결하면서 추가
     */
    final mainVideo = Container(
      alignment: Alignment.center,
      child: const Text(
        'Main Video',
      ),
    );

    final fullLayout = Column(
      children: [
        Expanded(
          child: mainVideo,
        ),
        const SizedBox(
          height: 80,
          child: Center(
            child: Text(
              'Side Videos',
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final compact =
            constraints.maxWidth < 360 || constraints.maxHeight < 240;

        /*
         * Overlay가 작으면
         * 메인 영상만 표시
         */
        if (compact) {
          return mainVideo;
        }

        /*
         * 충분히 크면
         * 메인 + 사이드 표시
         */
        return fullLayout;
      },
    );
  }
}
