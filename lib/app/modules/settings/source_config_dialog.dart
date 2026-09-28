import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/services/online_source_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 网络音乐源配置对话框：接口路径 + 高级字段映射 + 连通性测试。
Future<void> showSourceConfigDialog(BuildContext context) async {
  final settings = Get.find<SettingsService>();
  final sourceService = Get.find<OnlineSourceService>();
  final current =
      settings.source.value ?? const OnlineSourceConfig(baseUrl: '');

  final baseUrl = TextEditingController(text: current.baseUrl);
  final searchPath = TextEditingController(text: current.searchPath);
  final playPath = TextEditingController(text: current.playPath);
  final searchKeywordKey =
      TextEditingController(text: current.searchKeywordKey);
  final searchListKey = TextEditingController(text: current.searchListKey);
  final idKey = TextEditingController(text: current.idKey);
  final titleKey = TextEditingController(text: current.titleKey);
  final artistKey = TextEditingController(text: current.artistKey);
  final albumKey = TextEditingController(text: current.albumKey);
  final durationKey = TextEditingController(text: current.durationKey);
  final coverKey = TextEditingController(text: current.coverKey);
  final playIdParam = TextEditingController(text: current.playIdParam);
  final playUrlKey = TextEditingController(text: current.playUrlKey);

  OnlineSourceConfig buildConfig() => OnlineSourceConfig(
        baseUrl: baseUrl.text.trim(),
        searchPath: searchPath.text.trim(),
        playPath: playPath.text.trim(),
        searchKeywordKey: searchKeywordKey.text.trim(),
        searchListKey: searchListKey.text.trim(),
        idKey: idKey.text.trim(),
        titleKey: titleKey.text.trim(),
        artistKey: artistKey.text.trim(),
        albumKey: albumKey.text.trim(),
        durationKey: durationKey.text.trim(),
        coverKey: coverKey.text.trim(),
        playIdParam: playIdParam.text.trim(),
        playUrlKey: playUrlKey.text.trim(),
      );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        var testing = false;

        Future<void> testConnection() async {
          setState(() => testing = true);
          try {
            await sourceService.testConnection(buildConfig());
            Get.snackbar('连接成功', '网络源可用');
          } on AppException catch (e) {
            Get.snackbar('连接失败', e.message);
          } finally {
            setState(() => testing = false);
          }
        }

        Future<void> save() async {
          final config = buildConfig();
          final url = config.baseUrl;
          if (url.isEmpty || !url.startsWith('http')) {
            Get.snackbar('无法保存', 'API 地址需以 http(s):// 开头');
            return;
          }
          await settings.setSource(config);
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
          Get.snackbar('已保存', '网络源配置已更新');
        }

        return AlertDialog(
          title: const Text('网络音乐源配置'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(controller: baseUrl, label: 'API 地址', hint: 'https://example.com/api'),
                  _Field(controller: searchPath, label: '搜索接口路径', hint: '/search'),
                  _Field(controller: playPath, label: '取播放地址路径', hint: '/song/url'),
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('高级：请求参数与字段映射'),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      _Field(controller: searchKeywordKey, label: '搜索关键词参数名'),
                      _Field(controller: playIdParam, label: '取地址歌曲 id 参数名'),
                      _Field(controller: searchListKey, label: '搜索结果列表字段（支持 a.b 嵌套）'),
                      _Field(controller: idKey, label: '歌曲 id 字段'),
                      _Field(controller: titleKey, label: '标题字段'),
                      _Field(controller: artistKey, label: '歌手字段'),
                      _Field(controller: albumKey, label: '专辑字段'),
                      _Field(controller: durationKey, label: '时长字段（秒）'),
                      _Field(controller: coverKey, label: '封面字段'),
                      _Field(controller: playUrlKey, label: '播放地址字段'),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: testing ? null : testConnection,
                    icon: testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: const Text('测试连接'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                settings.setSource(null);
                Navigator.of(dialogContext).pop();
                Get.snackbar('已清除', '网络源配置已清除');
              },
              child: const Text('清除配置'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(onPressed: save, child: const Text('保存')),
          ],
        );
      },
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.hint});

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
