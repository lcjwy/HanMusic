import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';

/// 播放历史（F6）：记录实际开始播放的歌曲（进入播放态 ≥ 10s，
/// 由播放器提交），同一歌曲去重合并、时间倒序，超限淘汰最旧。
class HistoryService extends GetxService {
  HistoryService(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _now;

  /// 去重合并后的历史（时间倒序，同一歌曲仅保留最近一条）。
  final entries = <HistoryEntry>[].obs;

  Future<void> load() async {
    try {
      final raw = _store.read<String>(AppConstants.keyHistory);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = (json['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => HistoryEntry.fromJson(m.cast<String, dynamic>()))
          .whereType<HistoryEntry>()
          .toList();
      entries.assignAll(list);
    } on FormatException {
      // 损坏时按空历史处理
    } on TypeError {
      // 结构/字段类型损坏同理
    }
  }

  /// 记录一次播放：同曲去重置顶，超限淘汰最旧。
  Future<void> record(Song song) async {
    entries.removeWhere((e) => e.song.id == song.id);
    entries.insert(0, HistoryEntry(song: song, playedAt: _now()));
    if (entries.length > AppConstants.historyLimit) {
      entries.removeRange(AppConstants.historyLimit, entries.length);
    }
    await _persist();
  }

  /// 清空历史（数据管理）。
  Future<void> clear() async {
    entries.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final json = {'entries': entries.map((e) => e.toJson()).toList()};
    await _store.write(AppConstants.keyHistory, jsonEncode(json));
  }
}

/// 一条历史记录。
class HistoryEntry {
  const HistoryEntry({required this.song, required this.playedAt});

  final Song song;
  final DateTime playedAt;

  Map<String, dynamic> toJson() =>
      {'song': song.toJson(), 'playedAt': playedAt.toIso8601String()};

  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final songRaw = json['song'];
    if (songRaw is! Map) return null;
    return HistoryEntry(
      song: Song.fromJson(songRaw.cast<String, dynamic>()),
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
