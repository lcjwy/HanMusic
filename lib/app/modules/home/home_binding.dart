import 'package:get/get.dart';
import 'package:han_music/app/modules/dashboard/dashboard_controller.dart';
import 'package:han_music/app/modules/home/home_controller.dart';
import 'package:han_music/app/modules/library/library_controller.dart';
import 'package:han_music/app/modules/online/online_controller.dart';
import 'package:han_music/app/modules/player/player_controller.dart';
import 'package:han_music/app/modules/playlist/playlist_controller.dart';
import 'package:han_music/app/modules/settings/settings_controller.dart';

/// 主框架页依赖注入：各 Tab 的 ViewModel + 播放器页面 ViewModel。
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(HomeController.new, fenix: true);
    Get.lazyPut<DashboardController>(DashboardController.new, fenix: true);
    Get.lazyPut<LibraryController>(LibraryController.new, fenix: true);
    Get.lazyPut<PlaylistController>(PlaylistController.new, fenix: true);
    Get.lazyPut<OnlineController>(OnlineController.new, fenix: true);
    Get.lazyPut<SettingsController>(SettingsController.new, fenix: true);
    Get.lazyPut<PlayerController>(PlayerController.new, fenix: true);
  }
}
