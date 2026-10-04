import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/widgets/confirm_dialog.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/services/history_service.dart';
import 'package:han_music/app/services/player_service.dart';

/// 最近播放页（F6）：时间倒序、同曲去重，点击即以该列表为队列播放；
/// 支持清空（二次确认）。
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final history = Get.find<HistoryService>();
    final player = Get.find<PlayerService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('最近播放'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: '清空历史',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: history.entries.isEmpty
                  ? null
                  : () => _confirmClear(context, history),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final entries = history.entries;
        if (entries.isEmpty) {
          return const EmptyPlaceholder(
            icon: Icons.history,
            title: '还没有播放记录',
            subtitle: '播放歌曲并停留 10 秒后会记录在这里',
          );
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final song = entry.song;
            return ListTile(
              leading: CoverArt(url: song.coverUrl, size: 44, iconSize: 20),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${song.artist} · ${_formatTime(entry.playedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: song.missing
                  ? Text(
                      '文件缺失',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    )
                  : null,
              onTap: () =>
                  player.playQueue(entries.map((e) => e.song).toList(), initialIndex: index),
            );
          },
        );
      }),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryService history,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空播放历史',
      content: '将删除全部播放记录，确定继续？',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await history.clear();
      Get.snackbar('已完成', '播放历史已清空');
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final hm = '${two(time.hour)}:${two(time.minute)}';
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return '今天 $hm';
    }
    return '${time.year}-${two(time.month)}-${two(time.day)} $hm';
  }
}
