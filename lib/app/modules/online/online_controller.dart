import 'package:get/get.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/modules/home/home_controller.dart';
import 'package:han_music/app/services/online_source_service.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 在线音乐 ViewModel：防抖搜索、错误提示、结果播放。
class OnlineController extends GetxController {
  OnlineSourceService get _source => Get.find<OnlineSourceService>();
  PlayerService get _player => Get.find<PlayerService>();
  SettingsService get _settings => Get.find<SettingsService>();

  final query = ''.obs;

  /// 最近一次搜索错误的用户可读文案。
  final error = Rxn<String>();

  bool get hasSource => _settings.hasSource;

  void onQueryChanged(String value) {
    query.value = value;
    error.value = null;
    // 防抖路径不经 await，失败需在此呈现；否则网络错误只表现为空结果
    _source.searchDebounced(value, onError: (e) => error.value = e.message);
  }

  Future<void> searchNow() async {
    error.value = null;
    try {
      await _source.search(query.value);
    } on AppException catch (e) {
      error.value = e.message;
    }
  }

  /// 以当前结果为队列，从点击项开始播放（地址在起播时按需解析）。
  Future<void> playResult(int index) async {
    final songs = _source.results.toList();
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    await _player.playQueue(songs, initialIndex: index);
  }

  /// 跳转到设置页配置网络源。
  void openSourceSettings() {
    Get.find<HomeController>().switchTo(3);
  }
}
