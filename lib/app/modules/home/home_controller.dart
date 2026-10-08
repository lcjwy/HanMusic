import 'package:get/get.dart';

/// 主框架 Tab 状态。
class HomeController extends GetxController {
  /// 0=主页 1=本地音乐 2=歌单 3=在线音乐 4=设置。
  final tabIndex = 0.obs;

  void switchTo(int index) => tabIndex.value = index;
}
