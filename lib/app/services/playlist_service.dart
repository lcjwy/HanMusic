import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/io/local_file.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/core/utils/hash.dart';
import 'package:han_music/app/data/models/playlist.dart';
import 'package:han_music/app/data/models/song.dart';

/// 歌单服务：自建歌单 CRUD、内置收藏歌单、歌曲收藏，变更即持久化。
///
/// 歌曲以 [Song] 快照入列，同一歌单内按歌曲 id 去重；删除歌单仅解除
/// 引用关系，不删除歌曲本身（本地曲库与播放队列不受影响）。
class PlaylistService extends GetxService {
  PlaylistService(
    this._store, {
    void Function(String path)? fileDelete,
  }) : _fileDelete = fileDelete ?? localFileDelete;

  final KeyValueStore _store;
  final void Function(String path) _fileDelete;

  final playlists = <Playlist>[].obs;

  /// 收藏歌曲 id 集合（收藏歌单的镜像）：列表项/播放页 O(1) 判定用。
  final favoriteIds = Rx<Set<String>>(<String>{});

  Playlist? byId(String id) {
    for (final playlist in playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// 启动加载；首次使用或数据损坏时补建内置收藏歌单。
  Future<void> load() async {
    try {
      final raw = _store.read<String>(AppConstants.keyPlaylists);
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final list = (json['playlists'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Playlist.fromJson(m.cast<String, dynamic>()))
            .toList();
        playlists.assignAll(list);
      }
    } on FormatException {
      // 数据损坏时按空处理，下方补建收藏歌单
    } on TypeError {
      // 结构/字段类型损坏同理
    }
    if (byId(Playlist.favoriteId) == null) {
      playlists.insert(
        0,
        Playlist(
          id: Playlist.favoriteId,
          name: AppConstants.favoritePlaylistName,
          coverId: 'rose',
          songs: const [],
          createdAt: DateTime.now(),
          deletable: false,
        ),
      );
    }
    _syncFavoriteIds();
    await _persist();
  }

  /// 新建歌单，返回创建结果。
  Future<Playlist> create({
    required String name,
    String? coverId,
    String? coverPath,
  }) async {
    final id =
        'playlist-${stableHash('$name#${DateTime.now().microsecondsSinceEpoch}')}';
    final playlist = Playlist(
      id: id,
      name: name,
      coverId: coverId,
      coverPath: coverPath,
      songs: const [],
      createdAt: DateTime.now(),
    );
    playlists.add(playlist);
    await _persist();
    return playlist;
  }

  /// 重命名。内置收藏歌单不可重命名，返回 false。
  Future<bool> rename(String id, String name) async {
    final playlist = byId(id);
    final trimmed = name.trim();
    if (playlist == null || !playlist.deletable || trimmed.isEmpty) {
      return false;
    }
    if (trimmed == playlist.name) return true;
    _replace(playlist.copyWith(name: trimmed));
    await _persist();
    return true;
  }

  /// 删除歌单（歌曲本身不受影响），同时清理自定义封面文件。
  /// 内置收藏歌单不可删除，返回 false。
  Future<bool> delete(String id) async {
    final playlist = byId(id);
    if (playlist == null || !playlist.deletable) return false;
    _deleteCustomCoverFile(playlist);
    playlists.remove(playlist);
    await _persist();
    return true;
  }

  /// 清空全部歌单数据（数据管理用）：删除自建歌单、清空收藏歌单内歌曲；
  /// 内置收藏歌单本身保留。返回清理的自定义封面文件数。
  Future<int> clearAll() async {
    var removedFiles = 0;
    for (final playlist in playlists) {
      if (playlist.deletable) {
        _deleteCustomCoverFile(playlist);
        removedFiles++;
      }
    }
    playlists.removeWhere((p) => p.deletable);
    final fav = byId(Playlist.favoriteId);
    if (fav != null && fav.songs.isNotEmpty) {
      _replace(fav.copyWith(songs: const []));
    }
    _syncFavoriteIds();
    await _persist();
    return removedFiles;
  }

  /// 更新封面：选内置图时清掉旧自定义文件；换新自定义图时同样清理。
  Future<void> updateCover(
    String id, {
    required String? coverId,
    required String? coverPath,
  }) async {
    final playlist = byId(id);
    if (playlist == null) return;
    final oldCustom = playlist.coverPath;
    final dropCustom = oldCustom != null && oldCustom != coverPath;
    _replace(
      playlist.copyWith(
        coverId: coverId ?? playlist.coverId,
        coverPath: coverPath,
        clearCoverPath: coverPath == null,
      ),
    );
    if (dropCustom) _deleteCustomCoverFile(playlist);
    await _persist();
  }

  /// 批量加入歌曲（按歌曲 id 去重），返回新增/跳过数量。
  Future<({int added, int skipped})> addSongs(
    String playlistId,
    List<Song> songs,
  ) async {
    final playlist = byId(playlistId);
    if (playlist == null || songs.isEmpty) {
      return (added: 0, skipped: songs.length);
    }
    final known = playlist.songs.map((s) => s.id).toSet();
    final fresh = <Song>[];
    for (final song in songs) {
      if (known.add(song.id)) fresh.add(song);
    }
    if (fresh.isNotEmpty) {
      _replace(playlist.copyWith(songs: [...playlist.songs, ...fresh]));
      if (playlistId == Playlist.favoriteId) _syncFavoriteIds();
      await _persist();
    }
    return (added: fresh.length, skipped: songs.length - fresh.length);
  }

  /// 从歌单移除单曲（不删除歌曲本身）。返回是否发生移除。
  Future<bool> removeSong(String playlistId, String songId) async {
    final playlist = byId(playlistId);
    if (playlist == null) return false;
    final songs = List<Song>.of(playlist.songs);
    final before = songs.length;
    songs.removeWhere((s) => s.id == songId);
    if (songs.length == before) return false;
    _replace(playlist.copyWith(songs: songs));
    if (playlistId == Playlist.favoriteId) _syncFavoriteIds();
    await _persist();
    return true;
  }

  /// 拖拽排序（oldIndex/newIndex 为 ReorderableListView 语义）。
  Future<void> moveSong(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final playlist = byId(playlistId);
    if (playlist == null) return;
    final songs = List<Song>.of(playlist.songs);
    if (oldIndex < 0 || oldIndex >= songs.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, songs.length - 1);
    if (newIndex == oldIndex) return;
    songs.insert(newIndex, songs.removeAt(oldIndex));
    _replace(playlist.copyWith(songs: songs));
    await _persist();
  }

  /// 收藏/取消收藏。返回操作后是否已收藏。
  Future<bool> toggleFavorite(Song song) async {
    final playlist = byId(Playlist.favoriteId);
    if (playlist == null) return false;
    if (favoriteIds.value.contains(song.id)) {
      await removeSong(Playlist.favoriteId, song.id);
      return false;
    }
    await addSongs(Playlist.favoriteId, [song]);
    return true;
  }

  bool isFavorite(String songId) => favoriteIds.value.contains(songId);

  void _replace(Playlist updated) {
    final index = playlists.indexWhere((p) => p.id == updated.id);
    if (index >= 0) playlists[index] = updated;
  }

  void _syncFavoriteIds() {
    favoriteIds.value =
        byId(Playlist.favoriteId)?.songs.map((s) => s.id).toSet() ?? <String>{};
  }

  void _deleteCustomCoverFile(Playlist playlist) {
    final cover = playlist.coverPath;
    if (cover == null || cover.isEmpty) return;
    _fileDelete(cover);
  }

  Future<void> _persist() async {
    final json = {'playlists': playlists.map((p) => p.toJson()).toList()};
    await _store.write(AppConstants.keyPlaylists, jsonEncode(json));
  }
}
