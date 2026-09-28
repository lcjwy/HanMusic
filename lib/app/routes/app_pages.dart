import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/modules/home/home_binding.dart';
import 'package:han_music/app/modules/home/home_view.dart';
import 'package:han_music/app/modules/player/player_view.dart';

/// 路由表：页面与依赖绑定集中登记。
class AppPages {
  static final List<GetPage> pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(name: AppRoutes.player, page: () => const PlayerView()),
  ];
}
