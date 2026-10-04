import 'dart:async';
import 'dart:convert';

import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:http/http.dart' as http;

/// 网络音乐源通用适配器：按 [OnlineSourceConfig] 描述的接口形态发起
/// REST 调用与字段映射，不绑定任何具体平台。
///
/// 所有异常统一转为 [AppException]（message 为用户可读文案）。
class OnlineSourceAdapter {
  OnlineSourceAdapter(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  final OnlineSourceConfig config;
  final http.Client _client;

  /// 释放底层 HTTP 连接。适配器按单次请求创建使用，用毕即关；
  /// 注入共享 client 的测试场景下重复关闭无害。
  void close() => _client.close();

  /// 关键词搜索，返回统一 [Song] 列表。
  Future<List<Song>> search(String keyword) {
    return _guard(() async {
      final response = await _client
          .get(_uri(config.searchPath, {config.searchKeywordKey: keyword}))
          .timeout(AppConstants.requestTimeout);
      _ensureOk(response);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final rawList = _locate(data, config.searchListKey);
      if (rawList is! List) {
        throw const AppException('源返回格式无法解析：未找到结果列表');
      }
      final songs = <Song>[];
      for (final item in rawList) {
        if (item is Map) {
          final song = _songFromItem(item.cast<String, dynamic>());
          if (song != null) songs.add(song);
        }
      }
      return songs;
    });
  }

  /// 获取在线歌曲的可播放流地址。
  Future<String> resolvePlayUrl(Song song) {
    return _guard(() async {
      final rawId = song.id.startsWith('online-')
          ? song.id.substring('online-'.length)
          : song.id;
      final response = await _client
          .get(_uri(config.playPath, {config.playIdParam: rawId}))
          .timeout(AppConstants.requestTimeout);
      _ensureOk(response);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final url = _locate(data, config.playUrlKey)?.toString();
      if (url == null || url.isEmpty) {
        throw AppException('未找到「${song.title}」的可播放地址');
      }
      return url;
    });
  }

  /// 连通性测试：能完成一次搜索请求（HTTP 200 且 JSON 可解析）即视为可用。
  Future<void> testConnection() => search('test');

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException('连接源超时，请检查网络或源地址');
    } on Exception catch (e) {
      throw AppException('无法连接到音乐源', cause: e);
    }
  }

  Uri _uri(String path, Map<String, String> query) {
    // baseUrl 容错：用户配置带尾斜杠时归一化，避免出现双斜杠路径
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: query);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode != 200) {
      throw AppException('源响应异常（HTTP ${response.statusCode}）');
    }
  }

  /// 按 `a.b.c` 点路径逐级取嵌套字段，缺失返回 null。
  dynamic _locate(Object? data, String dottedPath) {
    Object? current = data;
    for (final segment in dottedPath.split('.')) {
      if (current is Map && current[segment] != null) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  Song? _songFromItem(Map<String, dynamic> item) {
    final rawId = _locate(item, config.idKey)?.toString() ?? '';
    if (rawId.isEmpty) return null; // 无 id 的结果无法取播放地址，跳过
    final durationValue = _locate(item, config.durationKey);
    final title = _locate(item, config.titleKey)?.toString();
    return Song(
      id: 'online-$rawId',
      title: (title == null || title.isEmpty) ? '未知标题' : title,
      artist: _locate(item, config.artistKey)?.toString() ?? Song.defaultArtist,
      album: _locate(item, config.albumKey)?.toString() ?? Song.defaultAlbum,
      duration: durationValue is num && durationValue > 0
          ? Duration(seconds: durationValue.toInt())
          : null,
      coverUrl: _locate(item, config.coverKey)?.toString(),
      source: SongSource.online,
      pathOrUrl: '', // 播放时经 resolvePlayUrl 获取
      addedAt: DateTime.now(),
    );
  }
}
