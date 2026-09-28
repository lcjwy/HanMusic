import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/modules/player/player_controller.dart';
import 'package:han_music/app/services/player_service.dart';

/// 全局迷你播放条：除播放页外的所有页面常驻底部。
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final player = Get.find<PlayerService>();

    return Obx(() {
      final song = player.current.value;
      if (song == null) return const SizedBox.shrink();

      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      );
    });
  }
}
