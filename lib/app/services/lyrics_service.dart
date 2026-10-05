import 'dart:convert';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/core/utils/lyrics.dart';
import 'package:han_music/app/data/models/song.dart';

/// 歌词解析器签名（PlayerService 注入用）。
typedef LyricsResolver =
    Future<ResolvedLyrics?> Function(Song song, {bool forceRefresh});

/// 歌词解析结果：文档 + 来源标识（播放页展示「AI 生成」用）。
class ResolvedLyrics {
  const ResolvedLyrics(
    this.document, {
    this.fromAi = false,
    this.manual = false,
  });

  final LyricsDocument document;
  final bool fromAi;

  /// 手动粘贴的歌词：优先级最高，不被 AI 结果覆盖。
  final bool manual;
}

/// 歌词服务：本地缓存 → 内嵌歌词 → 网络源歌词接口 → AI 的获取链路。
///
/// 缓存键为「曲名+歌手」规范化；手动粘贴永久保留且不被覆盖，
/// AI 结果可被重新获取覆盖；缓存无过期时间（歌词内容稳定）。
class LyricsService extends GetxService {
  LyricsService(
    this._store, {
    required this.readEmbedded,
    required this.readSourceLyrics,
    required this.isAiConfigured,
    required this.fetchAiLyrics,
  });

  final KeyValueStore _store;

  /// 本地歌曲内嵌歌词读取（Web 端为空实现）。
  final Future<String?> Function(String path) readEmbedded;

  /// 网络源歌词接口获取（未配置源时实现内应返回 null）。
  final Future<String?> Function(Song song) readSourceLyrics;

  /// AI 是否可用（已配置供应商且已填 Key）。
  final bool Function() isAiConfigured;

  /// AI 歌词获取（内部抛 AppException）。
  final Future<String> Function(Song song) fetchAiLyrics;

  static const _manualFlag = 'manual';
  static const _aiFlag = 'ai';
  static const _textFlag = 'text';

  /// 缓存篇数（数据管理占用展示）。
  final cacheCount = 0.obs;
  Future<void> _cacheWrites = Future<void>.value();

  Map<String, dynamic> _cache() {
    final raw = _store.read<String>(AppConstants.keyLyricsCache);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : {};
    } on FormatException {
      return {};
    }
  }

  /// 串行读改写，避免迟到请求用旧快照覆盖手动歌词或其他歌曲。
  Future<T> _mutateCache<T>(T Function(Map<String, dynamic>) mutate) {
    final result = _cacheWrites.then((_) async {
      final cache = _cache();
      final value = mutate(cache);
      await _store.write(AppConstants.keyLyricsCache, jsonEncode(cache));
      cacheCount.value = cache.length;
      return value;
    });
    _cacheWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  ResolvedLyrics? _manualLyrics(String key, Map<String, dynamic> cache) {
    final entry = cache[key];
    if (entry is! Map || entry[_manualFlag] != true) return null;
    final doc = _parseOf(entry);
    return doc == null ? null : ResolvedLyrics(doc, manual: true);
  }

  Future<ResolvedLyrics> _cacheFetched(
    String key,
    String text,
    LyricsDocument doc, {
    required bool fromAi,
  }) {
    return _mutateCache((cache) {
      final manual = _manualLyrics(key, cache);
      if (manual != null) return manual;
      cache[key] = {_textFlag: text, _aiFlag: fromAi, _manualFlag: false};
      return ResolvedLyrics(doc, fromAi: fromAi);
    });
  }

  String _cacheKeyOf(Song song) =>
      '${song.title.trim().toLowerCase()}|${song.artist.trim().toLowerCase()}';

  LyricsDocument? _parseOf(Object? entry) {
    if (entry is! Map) return null;
    final text = entry[_textFlag];
    return text is String ? LyricsDocument.parse(text) : null;
  }

  /// 歌词获取链路；全部来源失败返回 null（不抛错，AI 区分性提示由
  /// [pasteTip] 场景处理）。[forceRefresh] 跳过缓存重新获取（AI 结果
  /// 可覆盖，手动粘贴结果永不被覆盖）。
  Future<ResolvedLyrics?> resolve(
    Song song, {
    bool forceRefresh = false,
  }) async {
    final key = _cacheKeyOf(song);
    final cache = _cache();
    final cached = cache[key];
    if (!forceRefresh || (cached is Map && cached[_manualFlag] == true)) {
      final doc = _parseOf(cached);
      if (doc != null) {
        return ResolvedLyrics(
          doc,
          fromAi: cached is Map && cached[_aiFlag] == true,
          manual: cached is Map && cached[_manualFlag] == true,
        );
      }
    }

    if (song.source == SongSource.local) {
      final raw = await readEmbedded(song.pathOrUrl);
      final doc = LyricsDocument.parse(raw ?? '');
      if (doc != null) {
        await _cacheWrites;
        return _manualLyrics(key, _cache()) ?? ResolvedLyrics(doc);
      }
    }

    final fromSource = await readSourceLyrics(song);
    if (fromSource != null && fromSource.trim().isNotEmpty) {
      final doc = LyricsDocument.parse(fromSource);
      if (doc != null) {
        return _cacheFetched(key, fromSource, doc, fromAi: false);
      }
    }

    if (isAiConfigured()) {
      try {
        final text = await fetchAiLyrics(song);
        final doc = LyricsDocument.parse(text);
        if (doc == null) {
          throw const AppException('该歌曲无法通过 AI 获取歌词，建议手动粘贴');
        }
        return await _cacheFetched(key, text, doc, fromAi: true);
      } on Exception {
        // AI 失败（超时/Key 无效/余额不足/拒绝输出）：歌词链路静默降级
        return null;
      }
    }
    return null;
  }

  /// 手动粘贴歌词：永久保留，优先级高于 AI 与重新获取。
  Future<void> saveManual(Song song, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _mutateCache<void>((cache) {
      cache[_cacheKeyOf(song)] = {
        _textFlag: trimmed,
        _aiFlag: false,
        _manualFlag: true,
      };
    });
  }

  /// 清空全部歌词缓存（数据管理）。
  Future<void> clearCache() async {
    await _mutateCache<void>((cache) => cache.clear());
  }
}
