import 'package:get/get.dart';
import 'package:han_music/app/modules/player/player_controller.dart';

/// 播放页依赖注入：支撑不经主页直达播放页的深链场景。
class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlayerController>(PlayerController.new, fenix: true);
  }
}
