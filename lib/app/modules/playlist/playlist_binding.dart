import 'package:get/get.dart';
import 'package:han_music/app/modules/playlist/playlist_controller.dart';

/// 歌单页依赖注入。
class PlaylistBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlaylistController>(PlaylistController.new, fenix: true);
  }
}

/// 歌单详情依赖注入：支撑深链直达详情页。
class PlaylistDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlaylistDetailController>(
      PlaylistDetailController.new,
      fenix: true,
    );
  }
}
