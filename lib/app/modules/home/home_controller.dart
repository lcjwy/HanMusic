import 'package:get/get.dart';

/// 主框架 Tab 状态。
class HomeController extends GetxController {
  /// 0=本地音乐 1=歌单 2=在线音乐 3=设置。
  final tabIndex = 0.obs;

  void switchTo(int index) => tabIndex.value = index;
}
