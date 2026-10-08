import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/confirm_dialog.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/modules/library/library_controller.dart';
import 'package:han_music/app/modules/playlist/widgets/add_to_playlist_sheet.dart';
import 'package:han_music/app/services/library_import_service.dart';
import 'package:han_music/app/services/library_service.dart';

/// 本地音乐库页：极简搜索栏 + 列表头排序 + 虚拟化列表 + 多选删除。
class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LibraryController>();
    final library = Get.find<LibraryService>();

    return Column(
      children: [
        Obx(() {
          return controller.selecting
              ? _SelectionBar(controller: controller)
              : _SearchBar(controller: controller);
        }),
        const _ImportProgress(),
        Expanded(
          child: Obx(() {
            if (library.songs.isEmpty) {
              return EmptyPlaceholder(
                icon: Icons.library_music,
                title: '本地曲库还是空的',
                subtitle: '导入本地音频文件，开始你的音乐',
                actionLabel: '导入音乐',
                onAction: controller.importFiles,
              );
            }
            final songs = controller.visibleSongs();
            if (songs.isEmpty) {
              return const EmptyPlaceholder(
                icon: Icons.search_off,
                title: '没有匹配的歌曲',
              );
            }
            return Column(
              children: [
                _ListHeader(controller: controller, count: songs.length),
                Expanded(
                  child: ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return Obx(() {
                        final checked = controller.selected.contains(song);
                        return ListTile(
                          leading: controller.selecting
                              ? Checkbox(
                                  value: checked,
                                  onChanged: (_) =>
                                      controller.toggleSelected(song),
                                )
                              : CoverArt(
                                  url: song.coverUrl, size: 44, iconSize: 20),
                          title: Text(
                            song.missing
                                ? '${song.title}（文件缺失）'
                                : song.title,
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
                          selected: checked,
                          onTap: () => controller.selecting
                              ? controller.toggleSelected(song)
                              : controller.playVisible(index),
                          onLongPress: () => controller.toggleSelected(song),
                        );
                      });
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// 顶部搜索栏：仅保留搜索框，功能入口统一收进主页。
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        onChanged: (value) => controller.query.value = value,
        decoration: const InputDecoration(
          hintText: '搜索标题 / 歌手 / 专辑',
          prefixIcon: Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// 列表头：歌曲计数 + 排序方式选择（仅列表非空时展示）。
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.controller, required this.count});

  final LibraryController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Text(
            '共 $count 首',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const Spacer(),
          PopupMenuButton<LibrarySort>(
            tooltip: '排序方式',
            onSelected: (value) => controller.sortBy.value = value,
            itemBuilder: (_) => [
              for (final sort in LibrarySort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: controller.sortBy.value == sort,
                  child: Text(sort.label),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Obx(
                    () => Text(
                      controller.sortBy.value.label,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 多选模式顶栏：全选 / 删除 / 退出。
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 一次重建内只计算一次可见列表，避免条件与动作间状态漂移
      final visible = controller.visibleSongs();
      final selectedCount = controller.selected.length;
      final allSelected = visible.isNotEmpty && selectedCount >= visible.length;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Text(
              '已选 $selectedCount 项',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton(
              onPressed: visible.isEmpty
                  ? null
                  : () => allSelected
                      ? controller.clearSelection()
                      : controller.selected.addAll(visible),
              child: Text(allSelected ? '取消全选' : '全选'),
            ),
            IconButton(
              tooltip: '加入歌单',
              icon: const Icon(Icons.playlist_add),
              onPressed: selectedCount == 0
                  ? null
                  : () => showAddToPlaylistSheet(
                      context, songs: controller.selected.toList()),
            ),
            IconButton(
              tooltip: '移除所选',
              icon: const Icon(Icons.delete_outline),
              onPressed: selectedCount == 0
                  ? null
                  : () => _confirmRemove(context, controller),
            ),
            IconButton(
              tooltip: '退出选择',
              icon: const Icon(Icons.close),
              onPressed: controller.clearSelection,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _confirmRemove(
    BuildContext context,
    LibraryController controller,
  ) async {
    final count = controller.selected.length;
    final confirmed = await showConfirmDialog(
      context,
      title: '移除所选歌曲',
      content: '将从曲库索引移除 $count 首歌曲（不删除源文件），确定继续？',
      confirmLabel: '移除',
    );
    if (confirmed) {
      await controller.removeSelected();
    }
  }
}

/// 导入进度条：任务进行中显示在工具栏下方，可取消。
class _ImportProgress extends StatelessWidget {
  const _ImportProgress();

  @override
  Widget build(BuildContext context) {
    final importer = Get.find<LibraryImportService>();
    return Obx(() {
      if (!importer.importing.value) return const SizedBox.shrink();
      final total = importer.total.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在导入 ${importer.scanned.value}/$total：${importer.currentName.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: total > 0 ? importer.scanned.value / total : null,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '取消导入',
              icon: const Icon(Icons.close),
              onPressed: importer.cancel,
            ),
          ],
        ),
      );
    });
  }
}
