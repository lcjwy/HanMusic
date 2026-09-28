import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/modules/online/online_controller.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 在线音乐页：网络源搜索与播放（Phase E 接入通用适配器）。
class OnlineView extends StatelessWidget {
  const OnlineView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OnlineController>();
    final settings = Get.find<SettingsService>();

    return Obx(() {
      if (settings.source.value == null) {
        return EmptyPlaceholder(
          icon: Icons.cloud_off,
          title: '未配置网络音乐源',
          subtitle: '配置你自己的音乐 API 后，即可在线搜索与播放',
          actionLabel: '去设置',
          onAction: controller.openSourceSettings,
        );
      }
      return const EmptyPlaceholder(
        icon: Icons.cloud_sync,
        title: '在线搜索即将就绪',
      );
    });
  }
}
