import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/data/models/playlist.dart';
import 'package:han_music/app/modules/playlist/widgets/playlist_edit_dialog.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 歌单页 ViewModel：新建入口与详情跳转。
class PlaylistController extends GetxController {
  Future<void> openDetail(Playlist playlist) async {
    await Get.toNamed<void>(AppRoutes.playlistDetail, arguments: playlist.id);
  }

  Future<void> createPlaylist(BuildContext context) =>
      showPlaylistEditDialog(context);
}

/// 歌单详情 ViewModel：批量播放、单曲移除、拖拽排序、删除。
class PlaylistDetailController extends GetxController {
  PlaylistService get _service => Get.find<PlaylistService>();
  PlayerService get _player => Get.find<PlayerService>();

  late final String playlistId;

  Worker? _deletedWorker;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    playlistId = arg is String && arg.isNotEmpty
        ? arg
        : Playlist.favoriteId;
    // 详情页停留期间歌单被删除（或在别的入口清掉）：自动返回上一页
    _deletedWorker = ever(_service.playlists, (_) {
      if (_service.byId(playlistId) == null &&
          Get.currentRoute == AppRoutes.playlistDetail) {
        Get.back<void>();
      }
    });
  }

  @override
  void onClose() {
    _deletedWorker?.dispose();
    super.onClose();
  }

  /// 以歌单为队列从 [index] 开始播放。
  Future<void> playAt(int index) async {
    final playlist = _service.byId(playlistId);
    if (playlist == null || index < 0 || index >= playlist.songs.length) {
      return;
    }
    await _player.playQueue(playlist.songs, initialIndex: index);
  }

  /// 整单播放；[shuffle] 为 true 时随机顺序。
  Future<void> playAll({bool shuffle = false}) async {
    final playlist = _service.byId(playlistId);
    if (playlist == null) return;
    if (playlist.songs.isEmpty) {
      Get.snackbar('无法播放', '歌单还是空的');
      return;
    }
    final songs = playlist.songs.toList();
    if (shuffle) songs.shuffle();
    await _player.playQueue(songs, initialIndex: 0);
  }

  Future<void> move(int oldIndex, int newIndex) =>
      _service.moveSong(playlistId, oldIndex, newIndex);

  Future<void> removeSongAt(int index) async {
    final playlist = _service.byId(playlistId);
    if (playlist == null || index < 0 || index >= playlist.songs.length) return;
    final song = playlist.songs[index];
    await _service.removeSong(playlistId, song.id);
    Get.snackbar('已移除', '「${song.title}」已从歌单移除');
  }

  /// 删除歌单（调用前需 UI 二次确认）；删除后由监听自动返回。
  Future<void> deletePlaylist() async {
    await _service.delete(playlistId);
  }
}
