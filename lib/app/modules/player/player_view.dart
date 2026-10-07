import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:han_music/app/core/theme/app_theme.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/utils/lyrics.dart';
import 'package:han_music/app/core/widgets/aurora_background.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/core/widgets/gradient_slider_track.dart';
import 'package:han_music/app/data/models/play_mode.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/modules/player/player_controller.dart';
import 'package:han_music/app/modules/player/widgets/sleep_timer_sheet.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/playlist_service.dart';
import 'package:han_music/app/services/timer_service.dart';

/// 播放页：极光背景、封面、进度、播放控制、播放模式、音量、定时入口。
class PlayerView extends StatelessWidget {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final player = controller.player;
    final theme = Theme.of(context);

    return Scaffold(
      // 背景延伸到透明 AppBar 之后，形成沉浸式顶部
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('正在播放'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: PlayerController.showLyrics.value ? '专辑动画' : '歌词',
              icon: Icon(
                PlayerController.showLyrics.value ? Icons.album : Icons.lyrics,
              ),
              onPressed: controller.toggleLyricsView,
            ),
          ),
          Obx(() {
            final song = player.current.value;
            if (song == null) return const SizedBox.shrink();
            final favorite =
                Get.find<PlaylistService>().favoriteIds.value.contains(song.id);
            return IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                color: favorite ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: controller.toggleFavorite,
            );
          }),
          IconButton(
            icon: const Icon(Icons.queue_music),
            tooltip: '当前队列',
            onPressed: () => controller.openQueue(context),
          ),
        ],
      ),
      body: Obx(() {
        final song = player.current.value;
        final content = song == null
            ? const EmptyPlaceholder(
                icon: Icons.music_off,
                title: '当前没有播放任务',
              ) as Widget
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Obx(
                          () => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: PlayerController.showLyrics.value
                                ? _LyricsView(
                                    key: const ValueKey('lyrics'),
                                    player: player,
                                  )
                                : _AlbumDisc(
                                    key: ValueKey('album-${song.id}'),
                                    url: song.coverUrl,
                                    playing: player.playing.value,
                                  ),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                                timerActive
                                    ? Icons.timer
                                    : Icons.timer_outlined,
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
        // 极光背景铺满整页（含透明 AppBar 区域），前景内容浮于其上
        return Stack(
          fit: StackFit.expand,
          children: [
            const AuroraBackground(),
            content,
          ],
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

  Worker? _songSwitchWorker;

  @override
  void initState() {
    super.initState();
    // 切歌时丢弃未完成的拖拽：旧位置 seek 到新歌、或超出新歌时长
    // 触发 Slider 断言，都源于拖拽态跨歌曲残留
    _songSwitchWorker = ever<Song?>(widget.player.current, (_) {
      if (_dragValueMs != null) {
        setState(() => _dragValueMs = null);
      }
    });
  }

  @override
  void dispose() {
    _songSwitchWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Obx(() {
      final maxMs = player.duration.value.inMilliseconds;
      final positionMs = player.position.value.inMilliseconds;
      // 拖拽值同样钳制在当前时长内，歌曲中途切换时防御 Slider 断言
      final dragMs = _dragValueMs?.clamp(0, maxMs).toDouble();
      final value = dragMs ??
          (maxMs > 0 ? positionMs.clamp(0, maxMs) : 0).toDouble();
      return Row(
        children: [
          Text(
            formatDuration(
              Duration(milliseconds: dragMs?.toInt() ?? positionMs),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                trackShape: const GradientSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
                thumbColor: Colors.white,
                inactiveTrackColor:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
              ),
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

/// 专辑播放动画：播放中封面缓慢旋转的黑胶样式，暂停即停转。
class _AlbumDisc extends StatefulWidget {
  const _AlbumDisc({super.key, required this.url, required this.playing});

  final String? url;
  final bool playing;

  @override
  State<_AlbumDisc> createState() => _AlbumDiscState();
}

class _AlbumDiscState extends State<_AlbumDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.playing) _rotation.repeat();
  }

  @override
  void didUpdateWidget(_AlbumDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    widget.playing ? _rotation.repeat() : _rotation.stop();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (context, child) {
          // 播放中随旋转相位呼吸的彩色辉光；暂停定格为静息亮度
          final pulse = widget.playing
              ? 0.5 + 0.5 * math.sin(_rotation.value * 2 * math.pi)
              : 0.25;
          return Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.16 + 0.16 * pulse),
                  blurRadius: 36 + 20 * pulse,
                  spreadRadius: 2 + 2 * pulse,
                ),
                BoxShadow(
                  color: AppTheme.accentPink
                      .withValues(alpha: 0.10 + 0.12 * pulse),
                  blurRadius: 44 + 24 * pulse,
                  spreadRadius: 1 + 2 * pulse,
                ),
              ],
            ),
            child: child,
          );
        },
        child: RotationTransition(
          turns: _rotation,
          child: Center(
            child: ClipOval(
              child: SizedBox(
                width: 180,
                height: 180,
                child: CoverArt(
                  url: widget.url,
                  size: 180,
                  radius: 90,
                  iconSize: 56,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 歌词滚动视图：当前行高亮并自动居中跟随；拖动期间挂起跟随 3 秒；
/// 点击带时间戳的行跳转播放进度；无歌词展示占位。
class _LyricsView extends StatefulWidget {
  const _LyricsView({super.key, required this.player});

  final PlayerService player;

  @override
  State<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<_LyricsView> {
  static const _lineHeight = 44.0;

  final _scroll = ScrollController();
  Timer? _resumeTimer;
  bool _userScrolling = false;
  LyricsDocument? _lastDoc;
  int _lastFollowed = -2;

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    // 仅用户手指拖动（dragDetails 非空）才挂起自动跟随，惯性滚动不挂起
    final dragDetails = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails,
      ScrollUpdateNotification(:final dragDetails) => dragDetails,
      OverscrollNotification(:final dragDetails) => dragDetails,
      _ => null,
    };
    if (dragDetails != null) {
      _resumeTimer?.cancel();
      _userScrolling = true;
    } else if (notification is ScrollEndNotification && _userScrolling) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(seconds: 3), () {
        _userScrolling = false;
      });
    }
    return false;
  }

  void _follow(int index) {
    if (_userScrolling || index < 0 || !_scroll.hasClients) return;
    if (index == _lastFollowed) return;
    _lastFollowed = index;
    final viewport = _scroll.position.viewportDimension;
    final target = (index * _lineHeight + _lineHeight / 2 - viewport / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<PlayerController>();
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Obx(() {
        final doc = widget.player.lyrics.value;
        final position = widget.player.position.value;
        if (doc == null || doc.lines.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '暂无歌词',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => controller.pasteLyrics(context),
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text('手动粘贴歌词'),
                ),
              ],
            ),
          );
        }
        final showAiBadge = widget.player.lyricsFromAi.value;
        // 切歌（文档更换）：复位跟随状态，从头开始跟随
        final isNewDoc = !identical(doc, _lastDoc);
        if (isNewDoc) {
          _lastDoc = doc;
          _lastFollowed = -2;
        }
        final current = doc.hasTimestamps
            ? doc.currentIndexAt(position)
            : -1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // jumpTo 不进 build 期：避免布局期修改滚动位置触发异常
          if (isNewDoc && _scroll.hasClients) _scroll.jumpTo(0);
          _follow(current);
        });
        return Stack(
          children: [
            ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 8),
              itemCount: doc.lines.length,
              itemBuilder: (context, index) {
                final line = doc.lines[index];
                final isCurrent = index == current;
                return GestureDetector(
                  onTap: line.timestamp == null
                      ? null
                      : () => widget.player.seek(line.timestamp!),
                  child: SizedBox(
                    height: _lineHeight,
                    child: Center(
                      child: Text(
                        line.text.isEmpty ? '♪' : line.text,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (isCurrent
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.bodyMedium)
                            ?.copyWith(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (showAiBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI 生成',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: controller.refreshLyrics,
                        child: Icon(
                          Icons.refresh,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
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
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                trackShape: const GradientSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 13),
              ),
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
