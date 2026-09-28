import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/core/widgets/empty_placeholder.dart';
import 'package:han_music/app/modules/online/online_controller.dart';
import 'package:han_music/app/services/online_source_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 在线音乐页：网络源搜索与串流播放。
class OnlineView extends StatelessWidget {
  const OnlineView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OnlineController>();
    final settings = Get.find<SettingsService>();
    final source = Get.find<OnlineSourceService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: controller.onQueryChanged,
                  onSubmitted: (_) => controller.searchNow(),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '搜索在线音乐',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.travel_explore),
                onPressed: controller.searchNow,
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            settings.source.value; // 订阅源配置变化
            source.results.length;
            source.searching.value;
            if (!controller.hasSource) {
              return EmptyPlaceholder(
                icon: Icons.cloud_off,
                title: '未配置网络音乐源',
                subtitle: '配置你自己的音乐 API 后，即可在线搜索与播放',
                actionLabel: '去设置',
                onAction: controller.openSourceSettings,
              );
            }
            final error = controller.error.value;
            if (error != null) {
              return EmptyPlaceholder(
                icon: Icons.cloud_off,
                title: '搜索失败',
                subtitle: error,
                actionLabel: '重试',
                onAction: controller.searchNow,
              );
            }
            final songs = source.results.toList();
            if (source.searching.value && songs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (songs.isEmpty) {
              return EmptyPlaceholder(
                icon: Icons.travel_explore,
                title: controller.query.value.trim().isEmpty
                    ? '输入关键字搜索在线音乐'
                    : '未找到相关歌曲',
              );
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: CoverArt(url: song.coverUrl, size: 44, iconSize: 20),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${song.artist} - ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    formatDuration(song.duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => controller.playResult(index),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
