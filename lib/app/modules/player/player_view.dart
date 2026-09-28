import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/data/models/play_mode.dart';
import 'package:han_music/app/modules/player/player_controller.dart';
import 'package:han_music/app/modules/player/widgets/sleep_timer_sheet.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/timer_service.dart';

/// 播放页：封面、进度、播放控制、播放模式、音量、定时入口。
class PlayerView extends StatelessWidget {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final player = controller.player;

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: '当前队列',
            onPressed: () => controller.openQueue(context),
          ),
        ],
      ),
      body: Obx(() {
        final song = player.current.value;
        if (song == null) {
          return const EmptyPlaceholder(
            icon: Icons.music_off,
            title: '当前没有播放任务',
          );
        }
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: CoverArt(
                      url: song.coverUrl,
                      size: 240,
                      radius: 20,
                      iconSize: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  song.title,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '${song.artist} · ${song.album}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _Seekbar(player: player),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PlayModeButton(controller: controller),
                    IconButton(
                      tooltip: '上一曲',
                      iconSize: 36,
                      onPressed: controller.previous,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    _PlayPauseButton(controller: controller),
                    IconButton(
                      tooltip: '下一曲',
                      iconSize: 36,
                      onPressed: controller.next,
                      icon: const Icon(Icons.skip_next),
                    ),
                    Obx(() {
                      final timer = Get.find<TimerService>();
                      final timerActive = timer.active;
                      return IconButton(
                        tooltip: '睡眠定时',
                        icon: Icon(
                          timerActive ? Icons.timer : Icons.timer_outlined,
                          color: timerActive
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        onPressed: () => showSleepTimerSheet(context),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                _VolumeSlider(controller: controller),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// 进度条：拖拽期间暂停跟随，松手后 seek。
class _Seekbar extends StatefulWidget {
  const _Seekbar({required this.player});

  final PlayerService player;

  @override
  State<_Seekbar> createState() => _SeekbarState();
}

class _SeekbarState extends State<_Seekbar> {
  double? _dragValueMs;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Obx(() {
      final maxMs = player.duration.value.inMilliseconds;
      final positionMs = player.position.value.inMilliseconds;
      final value = _dragValueMs ??
          (maxMs > 0 ? positionMs.clamp(0, maxMs) : 0).toDouble();
      return Row(
        children: [
          Text(
            formatDuration(
              Duration(milliseconds: _dragValueMs?.toInt() ?? positionMs),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Slider(
              value: value,
              max: maxMs > 0 ? maxMs.toDouble() : 1,
              onChanged: maxMs <= 0
                  ? null
                  : (v) => setState(() => _dragValueMs = v),
              onChangeEnd: maxMs <= 0
                  ? null
                  : (v) {
                      widget.player
                          .seek(Duration(milliseconds: v.toInt()));
                      setState(() => _dragValueMs = null);
                    },
            ),
          ),
          Text(
            formatDuration(player.duration.value),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    });
  }
}

class _PlayModeButton extends StatelessWidget {
  const _PlayModeButton({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.player.playMode.value;
      return IconButton(
        tooltip: mode.label,
        icon: Icon(mode.icon),
        onPressed: controller.cyclePlayMode,
      );
    });
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.player.buffering.value) {
        return const SizedBox(
          width: 48,
          height: 48,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return IconButton(
        tooltip: controller.player.playing.value ? '暂停' : '播放',
        iconSize: 56,
        color: Theme.of(context).colorScheme.primary,
        icon: Icon(
          controller.player.playing.value
              ? Icons.pause_circle_filled
              : Icons.play_circle_filled,
        ),
        onPressed: controller.toggle,
      );
    });
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          Icon(
            Icons.volume_up,
            size: 20,
            color: Theme.of(context).colorScheme.outline,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 2),
              child: Slider(
                value: controller.player.volume.value,
                onChanged: controller.setVolume,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
