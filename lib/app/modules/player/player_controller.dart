import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/data/models/play_mode.dart';
import 'package:han_music/app/modules/player/widgets/queue_sheet.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 播放页 ViewModel：对全局 PlayerService 的薄转发 + 错误提示消费。
class PlayerController extends GetxController {
  PlayerService get player => Get.find<PlayerService>();

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
}
