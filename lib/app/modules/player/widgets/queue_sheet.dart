import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/modules/playlist/widgets/add_to_playlist_sheet.dart';
import 'package:han_music/app/services/player_service.dart';

/// 当前播放队列底部弹窗（F3/F5）：拖拽调整顺序、单曲移除、点击切歌、
/// 整个队列一键加入歌单。
Future<void> showQueueSheet(BuildContext context) {
  final player = Get.find<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Obx(() {
        final songs = player.queue.toList();
        final currentIndex = player.currentIndex.value;

        Widget header(String title, {VoidCallback? onAdd}) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: '加入歌单',
                    icon: const Icon(Icons.playlist_add),
                    onPressed: onAdd,
                  ),
                ],
              ),
            );

        if (songs.isEmpty) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header('当前队列（0）'),
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('队列为空'),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: songs.length,
                    onReorder: (oldIndex, newIndex) =>
                        player.moveInQueue(oldIndex, newIndex),
                    header: header(
                      '当前队列（${songs.length}）',
                      onAdd: () {
                        Navigator.of(sheetContext).pop();
                        showAddToPlaylistSheet(
                          context,
                          songs: player.queue.toList(),
                        );
                      },
                    ),
                    itemBuilder: (sheetItemContext, index) {
                      final song = songs[index];
                      final isCurrent = index == currentIndex;
                      return ListTile(
                        key: ValueKey('${song.id}-$index'),
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: isCurrent
                              ? Icon(
                                  Icons.graphic_eq,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                )
                              : Text(
                                  '${index + 1}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
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
                        selected: isCurrent,
                        trailing: IconButton(
                          tooltip: '移出队列',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => player.removeFromQueue(index),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          player.playAt(index);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      });
    },
  );
}
