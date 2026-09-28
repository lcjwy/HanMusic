import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/services/player_service.dart';

/// 当前播放队列底部弹窗：点击切歌（重排/删除属于歌单功能范围）。
Future<void> showQueueSheet(BuildContext context) {
  final player = Get.find<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Obx(() {
        final songs = player.queue.toList();
        final currentIndex = player.currentIndex.value;
        if (songs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('队列为空')),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('当前队列（${songs.length}）',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: songs.length,
                  itemBuilder: (_, index) {
                    final song = songs[index];
                    final isCurrent = index == currentIndex;
                    return ListTile(
                      leading: isCurrent
                          ? Icon(Icons.graphic_eq,
                              color: Theme.of(context).colorScheme.primary)
                          : Text('${index + 1}',
                              style: Theme.of(context).textTheme.bodySmall),
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
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        player.playAt(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      });
    },
  );
}
