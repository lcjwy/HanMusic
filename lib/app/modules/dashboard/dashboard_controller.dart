import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/modules/home/home_controller.dart';
import 'package:han_music/app/modules/library/library_controller.dart';
import 'package:han_music/app/services/history_service.dart';
import 'package:han_music/app/services/player_service.dart';

/// 主页 ViewModel：聚合各服务的展示入口，自身不持有业务状态。
class DashboardController extends GetxController {
  HistoryService get _history => Get.find<HistoryService>();
  PlayerService get _player => Get.find<PlayerService>();
  LibraryController get _library => Get.find<LibraryController>();
  HomeController get _home => Get.find<HomeController>();

  /// 按当前时段返回问候语。
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return '夜深了';
    if (hour < 11) return '早上好';
    if (hour < 13) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  /// 最近一条播放记录（无历史时为 null，主页隐藏「继续播放」）。
  HistoryEntry? get lastEntry =>
      _history.entries.isEmpty ? null : _history.entries.first;

  /// 打开最近播放页。
  void openHistory() => Get.toNamed(AppRoutes.history);

  /// 切到歌单标签页。
  void goToPlaylists() => _home.switchTo(1);

  /// 以最近播放列表为队列，从最近一首开始播（与最近播放页点击行为一致）。
  Future<void> resumeRecent() async {
    final entries = _history.entries;
    if (entries.isEmpty) return;
    final first = entries.first.song;
    final songs = entries.map((e) => e.song).toList();
    final index = songs.indexWhere((s) => s.id == first.id);
    await _player.playQueue(songs, initialIndex: index < 0 ? 0 : index);
  }

  // 导入入口：转发曲库 ViewModel 的动作，主页不重复实现扫描逻辑。
  Future<void> importFiles() => _library.importFiles();

  Future<void> importFolder() => _library.importFolder();
}
