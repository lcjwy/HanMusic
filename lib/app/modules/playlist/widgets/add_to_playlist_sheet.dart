import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/widgets/playlist_cover.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/modules/playlist/widgets/playlist_edit_dialog.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 「添加到歌单」底部面板：列出全部歌单（含收藏歌单）+ 新建入口。
/// 同一歌单内重复添加按歌曲 id 去重，并给出数量提示。
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required List<Song> songs,
}) {
  final service = Get.find<PlaylistService>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Obx(() {
        final playlists = service.playlists.toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  songs.length > 1 ? '添加 ${songs.length} 首歌曲到歌单' : '添加到歌单',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final playlist in playlists)
                      ListTile(
                        leading: PlaylistCoverArt(
                          coverId: playlist.coverId,
                          coverPath: playlist.coverPath,
                          size: 40,
                          radius: 6,
                          iconSize: 18,
                        ),
                        title: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${playlist.songs.length} 首'),
                        onTap: () async {
                          final result =
                              await service.addSongs(playlist.id, songs);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          _reportAdd(playlist.name, result);
                        },
                      ),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        child: const Icon(Icons.add, size: 20),
                      ),
                      title: const Text('新建歌单…'),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        final created = await showPlaylistEditDialog(context);
                        if (created == null) return;
                        final result =
                            await service.addSongs(created.id, songs);
                        _reportAdd(created.name, result);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    },
  );
}

void _reportAdd(String name, ({int added, int skipped}) result) {
  if (result.added == 0) {
    Get.snackbar(
      '未添加',
      result.skipped > 0 ? '所选歌曲均已在「$name」中' : '没有可添加的歌曲',
    );
    return;
  }
  Get.snackbar(
    '已添加',
    '已将 ${result.added} 首歌曲加入「$name」'
    '${result.skipped > 0 ? '，${result.skipped} 首已存在' : ''}',
  );
}
