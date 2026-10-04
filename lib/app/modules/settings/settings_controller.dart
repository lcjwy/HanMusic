import 'package:get/get.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/services/history_service.dart';
import 'package:han_music/app/services/library_service.dart';
import 'package:han_music/app/services/lyrics_service.dart';
import 'package:han_music/app/services/playlist_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 设置页 ViewModel：主题、网络源入口、播放行为、数据管理。
class SettingsController extends GetxController {
  SettingsService get _settings => Get.find<SettingsService>();

  Future<void> setThemeMode(AppThemeMode mode) => _settings.setThemeMode(mode);

  Future<void> setAutoSkipOnFail(bool value) =>
      _settings.setAutoSkipOnFail(value);

  /// 清空曲库索引（仅索引，不动源文件），调用前需 UI 二次确认。
  Future<void> clearLibrary() async {
    await Get.find<LibraryService>().clear();
    Get.snackbar('已完成', '曲库索引已清空');
  }

  /// 清空全部歌单数据（自建歌单删除、收藏歌单清空内容），调用前需 UI 二次确认。
  Future<void> clearPlaylists() async {
    await Get.find<PlaylistService>().clearAll();
    Get.snackbar('已完成', '歌单数据已清空');
  }

  /// 清空歌词缓存（AI/网络源获取的歌词将按需重新获取），调用前需 UI 二次确认。
  Future<void> clearLyricsCache() async {
    await Get.find<LyricsService>().clearCache();
    Get.snackbar('已完成', '歌词缓存已清空');
  }

  /// 清空播放历史，调用前需 UI 二次确认。
  Future<void> clearHistory() async {
    await Get.find<HistoryService>().clear();
    Get.snackbar('已完成', '播放历史已清空');
  }
}
