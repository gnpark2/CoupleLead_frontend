import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/media_tile.dart';
import '../media_layout_provider.dart';
import 'media_video_tile.dart';

class MediaLayout extends ConsumerWidget {
  final List<MediaTile> tiles;

  const MediaLayout({
    super.key,
    required this.tiles,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    if (tiles.isEmpty) {
      return const Center(
        child: Text(
          '공유 중인 화면이 없습니다.',
        ),
      );
    }

    final layout = ref.watch(
      mediaLayoutProvider,
    );

    MediaTile mainTile;

    final selected = tiles.where(
      (tile) => tile.id == layout.mainTrackId,
    );

    if (selected.isNotEmpty) {
      mainTile = selected.first;
    } else {
      mainTile = tiles.first;
    }

    final sideTiles = tiles
        .where(
          (tile) => tile.id != mainTile.id,
        )
        .toList();

    return Column(
      children: [
        Expanded(
          child: MediaVideoTile(
            track: mainTile.track,
            label: mainTile.label,
            main: true,
            onSelectMain: () {},
            onHide: () {
              ref
                  .read(
                    mediaLayoutProvider.notifier,
                  )
                  .hide(
                    mainTile.id,
                  );
            },
          ),
        ),
        if (sideTiles.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(
                8,
              ),
              itemCount: sideTiles.length,
              separatorBuilder: (
                context,
                index,
              ) =>
                  const SizedBox(
                width: 8,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                final tile = sideTiles[index];

                return SizedBox(
                  width: 220,
                  child: MediaVideoTile(
                    track: tile.track,
                    label: tile.label,
                    main: false,
                    onSelectMain: () {
                      ref
                          .read(
                            mediaLayoutProvider.notifier,
                          )
                          .selectMain(
                            tile.id,
                          );
                    },
                    onHide: () {
                      ref
                          .read(
                            mediaLayoutProvider.notifier,
                          )
                          .hide(
                            tile.id,
                          );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
