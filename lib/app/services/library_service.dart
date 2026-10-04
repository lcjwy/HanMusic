import 'dart:convert';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/io/local_file.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';

/// 本地曲库：导入索引的内存态 + GetStorage 持久化。
///
/// 只管理索引与导入产生的封面缓存文件，不触碰音频源文件本身。
class LibraryService extends GetxService {
  LibraryService(
    this._store, {
    bool Function(String path)? fileExists,
    void Function(String path)? fileDelete,
  })  : _fileExists = fileExists ?? localFileExists,
        _fileDelete = fileDelete ?? localFileDelete;

  final KeyValueStore _store;
  final bool Function(String path) _fileExists;
  final void Function(String path) _fileDelete;

  final songs = <Song>[].obs;

  /// 启动加载，并对本地文件做存在性校验（缺失条目标记 missing，UI 灰显）。
  /// 校验分块让出事件循环，避免大曲库下连续同步 stat 长时间阻塞 UI。
  Future<void> load() async {
    try {
      final raw = _store.read<String>(AppConstants.keyLibrary);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => Song.fromJson(m.cast<String, dynamic>()))
          .toList();
      const chunkSize = 128;
      for (var i = 0; i < list.length; i++) {
        list[i] = _markMissing(list[i]);
        if (i % chunkSize == chunkSize - 1 && i < list.length - 1) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      songs.assignAll(list);
    } on FormatException {
      // 索引损坏时按空曲库处理，等待重新导入
    } on TypeError {
      // 结构/字段类型损坏同理
    }
  }

  Song _markMissing(Song song) {
    if (song.source != SongSource.local) return song;
    return song.copyWith(missing: !_fileExists(song.pathOrUrl));
  }

  /// 批量导入，按歌曲 id（本地即路径哈希）去重——含批内重复与已入库重复，
  /// 返回实际新增数量。
  Future<int> addAll(Iterable<Song> incoming) async {
    final known = songs.map((s) => s.id).toSet();
    final fresh = <Song>[];
    for (final song in incoming) {
      if (known.add(song.id)) {
        fresh.add(song);
      }
    }
    if (fresh.isNotEmpty) {
      songs.addAll(fresh);
      await _persist();
    }
    return fresh.length;
  }

  /// 从曲库移除（仅删索引，不删除音频源文件；应用内封面缓存随之清理）。
  Future<void> removeSongs(Iterable<Song> targets) async {
    final ids = targets.map((s) => s.id).toSet();
    for (final song in songs.where((s) => ids.contains(s.id))) {
      _deleteCoverCache(song);
    }
    songs.removeWhere((s) => ids.contains(s.id));
    await _persist();
  }

  /// 清空曲库索引，并清理全部封面缓存文件。
  Future<void> clear() async {
    for (final song in songs) {
      _deleteCoverCache(song);
    }
    songs.clear();
    await _persist();
  }

  /// 删除歌曲的封面缓存文件。封面仅本地导入时落盘（应用专属目录），
  /// 不清理会随反复导入/删除无限累积。
  void _deleteCoverCache(Song song) {
    final cover = song.coverUrl;
    if (song.source != SongSource.local || cover == null || cover.isEmpty) {
      return;
    }
    _fileDelete(cover);
  }

  Future<void> _persist() async {
    await _store.write(
      AppConstants.keyLibrary,
      jsonEncode(songs.map((s) => s.toJson()).toList()),
    );
  }
}
