import 'package:get/get.dart';
import 'package:han_music/app/modules/home/home_controller.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 在线音乐 ViewModel：搜索与结果管理（通用适配器接入后填充）。
class OnlineController extends GetxController {
  SettingsService get _settings => Get.find<SettingsService>();

  final query = ''.obs;
  final searching = false.obs;

  bool get hasSource => _settings.hasSource;

  /// 跳转到设置页配置网络源。
  void openSourceSettings() {
    Get.find<HomeController>().switchTo(2);
  }
}
