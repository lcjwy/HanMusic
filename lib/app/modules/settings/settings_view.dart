import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/widgets/confirm_dialog.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/modules/settings/ai_config_dialog.dart';
import 'package:han_music/app/modules/settings/settings_controller.dart';
import 'package:han_music/app/modules/settings/source_config_dialog.dart';
import 'package:han_music/app/services/library_service.dart';
import 'package:han_music/app/services/lyrics_service.dart';
import 'package:han_music/app/services/playlist_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 设置页：外观 / 网络源 / 数据管理 / 关于。
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final settings = Get.find<SettingsService>();
    final library = Get.find<LibraryService>();
    final playlists = Get.find<PlaylistService>();

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
        const _SectionHeader('播放'),
        Obx(
          () => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('播放失败自动跳过'),
            subtitle: const Text('文件损坏或加载失败时自动切换下一曲'),
            value: settings.autoSkipOnFail.value,
            onChanged: controller.setAutoSkipOnFail,
          ),
        ),
        const _SectionHeader('网络源'),
        Obx(
          () {
            final source = settings.source.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('网络音乐源'),
              subtitle: Text(
                source?.baseUrl ?? '未配置（用于在线搜索与播放）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showSourceConfigDialog(context),
            );
          },
        ),
        const _SectionHeader('AI 服务'),
        Obx(
          () {
            final ai = settings.ai.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI 服务（歌词获取）'),
              subtitle: Text(
                ai == null ? '未配置（阶跃星辰 / 智谱 / DeepSeek）' : '${ai.provider.label} · ${ai.model}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAiConfigDialog(context),
            );
          },
        ),
        const _SectionHeader('数据'),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storage_outlined),
            title: const Text('占用情况'),
            subtitle: Text(
              '曲库 ${library.songs.length} 首 · '
              '歌单 ${playlists.playlists.length} 个 · '
              '歌词缓存 ${Get.find<LyricsService>().cacheCount.value} 篇',
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.library_music_outlined),
          title: const Text('清空曲库索引'),
          subtitle: const Text('仅移除索引，不删除源文件'),
          onTap: () => _confirmClearLibrary(context, controller),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.queue_music_outlined),
          title: const Text('清空歌单数据'),
          subtitle: const Text('删除自建歌单并清空收藏歌单内容'),
          onTap: () => _confirmClearPlaylists(context, controller),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lyrics_outlined),
          title: const Text('清空歌词缓存'),
          subtitle: const Text('删除本地保存的歌词，重新播放时按需获取'),
          onTap: () => _confirmClearLyrics(context, controller),
        ),
        const _SectionHeader('关于'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note),
          title: const Text('HanMusic'),
          subtitle: Text('v${AppConstants.appVersion}'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('开源许可'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'HanMusic',
            applicationVersion: AppConstants.appVersion,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearLibrary(
    BuildContext context,
    SettingsController controller,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空曲库索引',
      content: '将移除全部本地音乐索引（不删除源文件），确定继续？',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await controller.clearLibrary();
    }
  }

  Future<void> _confirmClearPlaylists(
    BuildContext context,
    SettingsController controller,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空歌单数据',
      content: '将删除全部自建歌单并清空收藏歌单内的歌曲（歌曲本身与曲库不受影响），确定继续？',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await controller.clearPlaylists();
    }
  }

  Future<void> _confirmClearLyrics(
    BuildContext context,
    SettingsController controller,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空歌词缓存',
      content: '将删除本地保存的全部歌词（含手动粘贴），再次播放需重新获取，确定继续？',
      confirmLabel: '清空',
    );
    if (confirmed) {
      await controller.clearLyricsCache();
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
