import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/data/models/play_mode.dart';
import 'package:han_music/app/modules/player/widgets/queue_sheet.dart';
import 'package:han_music/app/services/lyrics_service.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 播放页 ViewModel：对全局 PlayerService 的薄转发 + 错误提示消费。
class PlayerController extends GetxController {
  PlayerService get player => Get.find<PlayerService>();

  /// 播放页内容视图（会话内记忆，弹出页面不重置）：
  /// false=专辑播放动画，true=歌词滚动。
  static final showLyrics = false.obs;

  Worker? _errorWorker;

  @override
  void onInit() {
    super.onInit();
    _errorWorker = ever<String?>(player.lastError, (message) {
      if (message == null) return;
      Get.snackbar(
        '播放失败',
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      player.lastError.value = null;
    });
  }

  @override
  void onClose() {
    _errorWorker?.dispose();
    super.onClose();
  }

  Future<void> toggle() => player.togglePlayPause();

  Future<void> next() => player.next();

  Future<void> previous() => player.previous();

  Future<void> seek(Duration target) => player.seek(target);

  Future<void> setVolume(double value) => player.setVolume(value);

  void cyclePlayMode() {
    final order = PlayMode.values;
    final nextMode = order[(order.indexOf(player.playMode.value) + 1) % order.length];
    player.setPlayMode(nextMode);
  }

  void openQueue(BuildContext context) => showQueueSheet(context);

  /// 收藏/取消收藏当前歌曲，返回操作后是否已收藏。
  Future<bool> toggleFavorite() async {
    final song = player.current.value;
    if (song == null) return false;
    return Get.find<PlaylistService>().toggleFavorite(song);
  }

  /// 切换「专辑动画 / 歌词滚动」两种内容视图。
  void toggleLyricsView() => showLyrics.value = !showLyrics.value;

  /// 重新获取当前歌曲歌词（AI 结果可被覆盖，手动粘贴保留）。
  Future<void> refreshLyrics() => player.refreshLyrics();

  /// 手动粘贴歌词：优先级最高，永不被 AI 覆盖。
  Future<void> pasteLyrics(BuildContext context) async {
    final song = player.current.value;
    if (song == null) return;
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('粘贴歌词'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              maxLines: 12,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '粘贴 LRC 或纯文本歌词…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty) return;
    await Get.find<LyricsService>().saveManual(song, text);
    await player.refreshLyrics();
    Get.snackbar('已保存', '手动粘贴的歌词将优先展示');
  }
}
