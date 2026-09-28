import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/modules/settings/settings_controller.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 设置页：外观 / 网络源 / 数据管理 / 关于。
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final settings = Get.find<SettingsService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const _SectionHeader('外观'),
        Obx(
          () => SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(
                value: AppThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('系统'),
              ),
              ButtonSegment(
                value: AppThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('浅色'),
              ),
              ButtonSegment(
                value: AppThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('深色'),
              ),
            ],
            selected: {settings.themeMode.value},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
        ),
        const _SectionHeader('网络源'),
        Obx(
          () {
            final source = settings.source.value;
            return ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('网络音乐源'),
              subtitle: Text(
                source?.baseUrl ?? '未配置（用于在线搜索与播放）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.snackbar('提示', '网络源配置即将就绪'),
            );
          },
        ),
        const _SectionHeader('数据'),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text('清空曲库索引'),
          subtitle: const Text('仅移除索引，不删除源文件'),
          onTap: () => _confirmClearLibrary(context, controller),
        ),
        const _SectionHeader('关于'),
        const ListTile(
          leading: Icon(Icons.music_note),
          title: Text('HanMusic'),
          subtitle: Text('v0.1.0 · MVP'),
        ),
      ],
    );
  }

  Future<void> _confirmClearLibrary(
    BuildContext context,
    SettingsController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空曲库索引'),
        content: const Text('将移除全部本地音乐索引（不删除源文件），确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.clearLibrary();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
