import 'dart:async';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/remote/online_source_adapter.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 网络音乐源服务：防抖搜索、结果序校验、播放地址解析。
class OnlineSourceService extends GetxService {
  OnlineSourceService({
    OnlineSourceAdapter Function(OnlineSourceConfig config)? adapterFactory,
  }) : _adapterFactory =
            adapterFactory ?? ((config) => OnlineSourceAdapter(config));

  final OnlineSourceAdapter Function(OnlineSourceConfig config)
      _adapterFactory;

  final searching = false.obs;
  final results = <Song>[].obs;

  Timer? _debounceTimer;
  int _searchSeq = 0;

  /// 输入防抖触发搜索；空关键字清空结果。
  ///
  /// 防抖路径的 Future 不经调用方 await，失败经 [onError] 呈现，
  /// 否则网络异常会静默丢失（界面只会显示"未找到相关歌曲"）。
  void searchDebounced(
    String keyword, {
    void Function(AppException error)? onError,
  }) {
    _debounceTimer?.cancel();
    if (keyword.trim().isEmpty) {
      results.clear();
      searching.value = false;
      return;
    }
    _debounceTimer = Timer(AppConstants.searchDebounce, () {
      unawaited(
        search(keyword).catchError((Object e) {
          if (e is AppException) onError?.call(e);
        }),
      );
    });
  }

  /// 立即搜索：取消待触发的防抖任务，避免同一关键词二次请求；
  /// 旧请求晚到不覆盖新结果，失败抛 [AppException]。
  Future<void> search(String keyword) async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final config = _requireConfig();
    final seq = ++_searchSeq;
    searching.value = true;
    final adapter = _adapterFactory(config);
    try {
      final songs = await adapter.search(keyword.trim());
      if (seq == _searchSeq) results.assignAll(songs);
    } on AppException {
      if (seq == _searchSeq) {
        results.clear();
        rethrow;
      }
    } finally {
      // 适配器为单次请求而建，用毕释放底层连接
      adapter.close();
      if (seq == _searchSeq) searching.value = false;
    }
  }

  /// 解析在线歌曲播放地址（PlayerService 的 URL resolver 入口）。
  Future<String> resolveForPlayer(Song song) async {
    final adapter = _adapterFactory(_requireConfig());
    try {
      return await adapter.resolvePlayUrl(song);
    } finally {
      adapter.close();
    }
  }

  /// 解析在线歌曲歌词（PlayerService 的歌词 resolver 入口）。
  /// 未配置/失败一律返回 null：歌词获取不影响播放。
  Future<String?> resolveLyrics(Song song) async {
    final config = Get.find<SettingsService>().source.value;
    if (config == null || config.baseUrl.trim().isEmpty) return null;
    final adapter = _adapterFactory(config);
    try {
      return await adapter.resolveLyrics(song);
    } on AppException {
      return null;
    } finally {
      adapter.close();
    }
  }

  /// 连通性测试：可用即正常返回，不可用抛 [AppException]。
  Future<void> testConnection(OnlineSourceConfig config) async {
    final adapter = _adapterFactory(config);
    try {
      await adapter.testConnection();
    } finally {
      adapter.close();
    }
  }

  OnlineSourceConfig _requireConfig() {
    final config = Get.find<SettingsService>().source.value;
    if (config == null || config.baseUrl.trim().isEmpty) {
      throw const AppException('尚未配置网络音乐源');
    }
    return config;
  }
}
