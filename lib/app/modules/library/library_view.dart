import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/modules/library/library_controller.dart';
import 'package:han_music/app/services/library_service.dart';

/// 本地音乐库页：搜索 + 排序 + 虚拟化列表。
class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LibraryController>();
    final library = Get.find<LibraryService>();

    return Column(
      children: [
        _Toolbar(controller: controller),
        Expanded(
          child: Obx(() {
            // 显式订阅曲库变化；查询与排序在 visibleSongs 内同步读取
            library.songs.length;
            final songs = controller.visibleSongs();
            if (library.songs.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.library_music,
                title: '本地曲库还是空的',
                subtitle: '导入本地音频文件，开始你的音乐',
                actionLabel: '导入音乐',
                onAction: _stubImport,
              );
            }
            if (songs.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.search_off,
                title: '没有匹配的歌曲',
              );
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: CoverArt(url: song.coverUrl, size: 44, iconSize: 20),
                  title: Text(
                    song.missing ? '${song.title}（文件缺失）' : song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: song.missing
                        ? TextStyle(color: Theme.of(context).disabledColor)
                        : null,
                  ),
                  subtitle: Text(
                    '${song.artist} - ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    formatDuration(song.duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => controller.playVisible(index),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => controller.query.value = value,
              decoration: const InputDecoration(
                hintText: '搜索标题 / 歌手 / 专辑',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          PopupMenuButton<LibrarySort>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (value) => controller.sortBy.value = value,
            itemBuilder: (_) => [
              for (final sort in LibrarySort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
          IconButton(
            tooltip: '导入音乐',
            icon: const Icon(Icons.playlist_add),
            onPressed: _stubImport,
          ),
        ],
      ),
    );
  }
}

void _stubImport() {
  Get.snackbar('提示', '导入功能即将就绪');
}
