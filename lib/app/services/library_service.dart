import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';

/// 本地曲库：导入索引的内存态 + GetStorage 持久化。
///
/// 只管理索引，不触碰源文件本身。
class LibraryService extends GetxService {
  LibraryService(this._store, {bool Function(String path)? fileExists})
      : _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final KeyValueStore _store;
  final bool Function(String path) _fileExists;

  final songs = <Song>[].obs;

  /// 启动加载，并对本地文件做存在性校验（缺失条目标记 missing，UI 灰显）。
  Future<void> load() async {
    final raw = _store.read<String>(AppConstants.keyLibrary);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      songs.assignAll(list.map(Song.fromJson).map(_markMissing).toList());
    } on FormatException {
      // 索引损坏时按空曲库处理，等待重新导入
    }
  }

  Song _markMissing(Song song) {
    if (song.source != SongSource.local) return song;
    return song.copyWith(missing: !_fileExists(song.pathOrUrl));
  }

  bool containsPath(String path) =>
      songs.any((s) => s.source == SongSource.local && s.pathOrUrl == path);

  /// 批量导入，按本地路径去重，返回实际新增数量。
  int addAll(Iterable<Song> incoming) {
    final fresh = incoming.where((s) => !containsPath(s.pathOrUrl)).toList();
    if (fresh.isNotEmpty) {
      songs.addAll(fresh);
      _persist();
    }
    return fresh.length;
  }

  /// 从曲库移除（仅删索引，不删除源文件）。
  Future<void> removeSongs(Iterable<Song> targets) async {
    final ids = targets.map((s) => s.id).toSet();
    songs.removeWhere((s) => ids.contains(s.id));
    await _persist();
  }

  /// 清空曲库索引。
  Future<void> clear() async {
    songs.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _store.write(
      AppConstants.keyLibrary,
      jsonEncode(songs.map((s) => s.toJson()).toList()),
    );
  }
}
