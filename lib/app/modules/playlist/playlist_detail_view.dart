import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/confirm_dialog.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/core/widgets/playlist_cover.dart';
import 'package:han_music/app/data/models/playlist.dart';
import 'package:han_music/app/modules/playlist/playlist_controller.dart';
import 'package:han_music/app/modules/playlist/widgets/playlist_edit_dialog.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 歌单详情：头部（封面/名称/整单播放）+ 可拖拽排序列表 + 单曲移除。
class PlaylistDetailView extends StatelessWidget {
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistDetailController>();
    final service = Get.find<PlaylistService>();

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(service.byId(controller.playlistId)?.name ?? '歌单'),
        ),
        actions: [
          Obx(() {
            final playlist = service.byId(controller.playlistId);
            if (playlist == null) return const SizedBox.shrink();
            return IconButton(
              tooltip: '编辑歌单',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  showPlaylistEditDialog(context, existing: playlist),
            );
          }),
          Obx(() {
            final playlist = service.byId(controller.playlistId);
            if (playlist == null || !playlist.deletable) {
              return const SizedBox.shrink();
            }
            return IconButton(
              tooltip: '删除歌单',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, controller, playlist),
            );
          }),
        ],
      ),
      body: Obx(() {
        final playlist = service.byId(controller.playlistId);
        if (playlist == null) {
          // 正常情况下删除会自动返回；此态兜底深链指向已删歌单
          return const EmptyPlaceholder(
            icon: Icons.playlist_remove,
            title: '歌单不存在',
          );
        }
        final songs = playlist.songs;
        return Column(
          children: [
            _Header(playlist: playlist, controller: controller),
            const Divider(height: 1),
            Expanded(
              child: songs.isEmpty
                  ? const EmptyPlaceholder(
                      icon: Icons.queue_music,
                      title: '歌单还是空的',
                      subtitle: '在本地音乐多选加入，或在线音乐长按歌曲加入',
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: songs.length,
                      onReorder: controller.move,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return ListTile(
                          key: ValueKey(song.id),
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: CoverArt(
                              url: song.coverUrl,
                              size: 44,
                              iconSize: 20,
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            formatDuration(song.duration),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => controller.playAt(index),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlaylistDetailController controller,
    Playlist playlist,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除歌单',
      content: '将删除歌单「${playlist.name}」（共 ${playlist.songs.length} 首），'
          '歌曲本身不受影响，确定继续？',
      confirmLabel: '删除',
    );
    if (confirmed) {
      await controller.deletePlaylist();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.playlist, required this.controller});

  final Playlist playlist;
  final PlaylistDetailController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          PlaylistCoverArt(
            coverId: playlist.coverId,
            coverPath: playlist.coverPath,
            size: 72,
            radius: 10,
            iconSize: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.songs.length} 首',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '随机播放',
            icon: const Icon(Icons.shuffle),
            onPressed: () => controller.playAll(shuffle: true),
          ),
          IconButton(
            tooltip: '播放全部',
            iconSize: 40,
            icon: Icon(
              Icons.play_circle_fill,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => controller.playAll(),
          ),
        ],
      ),
    );
  }
}
