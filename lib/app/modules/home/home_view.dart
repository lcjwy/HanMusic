import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/theme/app_theme.dart';
import 'package:han_music/app/modules/dashboard/dashboard_view.dart';
import 'package:han_music/app/modules/home/home_controller.dart';
import 'package:han_music/app/modules/library/library_view.dart';
import 'package:han_music/app/modules/online/online_view.dart';
import 'package:han_music/app/modules/player/widgets/mini_player_bar.dart';
import 'package:han_music/app/modules/playlist/playlist_view.dart';
import 'package:han_music/app/modules/settings/settings_view.dart';

/// 主框架：窄屏底部导航、宽屏侧边导航（NavigationRail），布局自适应。
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  static const _widthThreshold = 900.0;

  static const _destinations = [
    (Icons.home_outlined, Icons.home, '主页'),
    (Icons.library_music_outlined, Icons.library_music, '本地音乐'),
    (Icons.queue_music_outlined, Icons.queue_music, '歌单'),
    (Icons.cloud_off_outlined, Icons.cloud_outlined, '在线音乐'),
    (Icons.settings_outlined, Icons.settings, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 内容区极淡对角流彩：紫入青出，列表页保持简洁只做氛围
    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.07),
            Colors.transparent,
            AppTheme.accentCyan.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Obx(
              () => IndexedStack(
                index: controller.tabIndex.value,
                children: const [
                  DashboardView(),
                  LibraryView(),
                  PlaylistView(),
                  OnlineView(),
                  SettingsView(),
                ],
              ),
            ),
          ),
          const MiniPlayerBar(),
        ],
      ),
    );
    final wide = MediaQuery.sizeOf(context).width >= _widthThreshold;

    return Scaffold(
      body: wide
          ? Row(
              children: [
                Obx(
                  () => NavigationRail(
                    selectedIndex: controller.tabIndex.value,
                    onDestinationSelected: controller.switchTo,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.seedColor,
                              AppTheme.accentPink,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    destinations: [
                      for (final (icon, selectedIcon, label) in _destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selectedIcon),
                          label: Text(label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : Obx(
              () => NavigationBar(
                selectedIndex: controller.tabIndex.value,
                onDestinationSelected: controller.switchTo,
                destinations: [
                  for (final (icon, selectedIcon, label) in _destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selectedIcon),
                      label: label,
                    ),
                ],
              ),
            ),
    );
  }
}
