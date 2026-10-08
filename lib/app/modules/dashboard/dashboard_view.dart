import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/theme/app_theme.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/modules/dashboard/dashboard_controller.dart';
import 'package:han_music/app/modules/library/bili_import_dialog.dart';

/// 主页：问候语 + 功能大卡片入口（最近播放 / 歌单 / 导入）+ 继续播放。
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text(controller.greeting, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _EntryCard(
                  icon: Icons.history,
                  title: '最近播放',
                  subtitle: '重新听听最近的歌曲',
                  onTap: controller.openHistory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EntryCard(
                  icon: Icons.queue_music,
                  title: '我的歌单',
                  subtitle: '整理你的音乐收藏',
                  onTap: controller.goToPlaylists,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _EntryCard(
          icon: Icons.library_add,
          title: '导入本地音乐',
          subtitle: '从文件、文件夹或 B站缓存导入',
          wide: true,
          onTap: () => _showImportSheet(context, controller),
        ),
        const _ResumeSection(),
      ],
    );
  }

  /// 导入方式底部单：文件 / 文件夹 / B站缓存。
  void _showImportSheet(BuildContext context, DashboardController controller) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.audio_file),
              title: const Text('导入文件'),
              subtitle: const Text('选择一个或多个音频文件'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.importFiles();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('导入文件夹'),
              subtitle: const Text('扫描整个文件夹下的音频'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.importFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('导入 B站缓存'),
              subtitle: const Text('识别本机 B站客户端的音频缓存'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showBiliImportDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能入口卡片：轻渐变底 + 渐变圆底图标，横排时侧向布局、独占一行时横向布局。
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// true 时独占整行（横向布局），false 时与另一张卡片等分（纵向布局）。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
              AppTheme.accentCyan.withValues(alpha: isDark ? 0.13 : 0.08),
            ],
          ),
        ),
        child: wide
            ? Row(
                children: [
                  _GradientIconBadge(icon: icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Texts(
                        title: title, subtitle: subtitle, theme: theme),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.outline),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GradientIconBadge(icon: icon),
                  const SizedBox(height: 12),
                  _Texts(title: title, subtitle: subtitle, theme: theme),
                ],
              ),
      ),
    );
  }
}

/// 卡片文字：标题 + 副标题，最多两行防溢出。
class _Texts extends StatelessWidget {
  const _Texts({
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final String title;
  final String subtitle;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

/// 渐变圆底图标：与侧边导航 logo 同风格（紫罗兰 → 粉）。
class _GradientIconBadge extends StatelessWidget {
  const _GradientIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.seedColor, AppTheme.accentPink],
        ),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

/// 继续播放区：有播放历史时展示最近一首，点击以历史队列为队列播放。
class _ResumeSection extends StatelessWidget {
  const _ResumeSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final theme = Theme.of(context);

    return Obx(() {
      final entry = controller.lastEntry;
      if (entry == null) return const SizedBox.shrink();
      final song = entry.song;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('继续播放', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CoverArt(url: song.coverUrl, size: 48, iconSize: 22),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: '播放',
                icon: Icon(
                  Icons.play_circle_fill,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                onPressed: controller.resumeRecent,
              ),
              onTap: controller.resumeRecent,
            ),
          ),
        ],
      );
    });
  }
}
