import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/core/theme/app_theme.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/modules/player/player_controller.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/timer_service.dart';

/// 全局迷你播放条：除播放页外的所有页面常驻底部，顶部带渐变进度线。
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final player = Get.find<PlayerService>();
    final theme = Theme.of(context);

    return Obx(() {
      final song = player.current.value;
      if (song == null) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 渐变进度线：与播放页进度条同款配色，随播放推进
          Obx(() {
            final durationMs = player.duration.value.inMilliseconds;
            final fraction = durationMs > 0
                ? (player.position.value.inMilliseconds / durationMs)
                    .clamp(0.0, 1.0)
                : 0.0;
            return Container(
              height: 3,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppTheme.progressGradient,
                    ),
                  ),
                ),
              ),
            );
          }),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CoverArt(url: song.coverUrl, size: 44, iconSize: 20),
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
              onTap: () => Get.toNamed(AppRoutes.player),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() {
                    final timer = Get.find<TimerService>();
                    final remaining = timer.remaining.value;
                    if (remaining != null) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          formatDuration(remaining),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    if (timer.stopAfterCurrent.value) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '播完停',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(
                    () => IconButton(
                      tooltip: player.playing.value ? '暂停' : '播放',
                      icon: Icon(
                        player.playing.value
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                      ),
                      onPressed: controller.toggle,
                    ),
                  ),
                  IconButton(
                    tooltip: '下一曲',
                    icon: const Icon(Icons.skip_next),
                    onPressed: controller.next,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
