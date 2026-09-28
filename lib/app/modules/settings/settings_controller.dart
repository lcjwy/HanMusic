import 'package:get/get.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/services/library_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 设置页 ViewModel：主题、网络源入口、数据管理。
class SettingsController extends GetxController {
  SettingsService get _settings => Get.find<SettingsService>();

  Future<void> setThemeMode(AppThemeMode mode) => _settings.setThemeMode(mode);

  /// 清空曲库索引（仅索引，不动源文件），调用前需 UI 二次确认。
  Future<void> clearLibrary() async {
    await Get.find<LibraryService>().clear();
    Get.snackbar('已完成', '曲库索引已清空');
  }
}
