import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/widgets/playlist_cover.dart';
import 'package:han_music/app/data/models/playlist.dart';
import 'package:han_music/app/modules/playlist/playlist_controller.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 歌单页：封面网格（含「新建歌单」入口），点击进入详情。
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistController>();
    final service = Get.find<PlaylistService>();

    return Obx(() {
      final playlists = service.playlists.toList();
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: playlists.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CreateTile(onTap: () => controller.createPlaylist(context));
          }
          final playlist = playlists[index - 1];
          return _PlaylistTile(
            playlist: playlist,
            onTap: () => controller.openDetail(playlist),
          );
        },
      );
    });
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              '新建歌单',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist, required this.onTap});

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PlaylistCoverArt(
                coverId: playlist.coverId,
                coverPath: playlist.coverPath,
                radius: 10,
                expand: true,
                iconSize: 36,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              '${playlist.songs.length} 首',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
