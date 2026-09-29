import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/services/online_source_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 网络音乐源配置对话框：接口路径 + 高级字段映射 + 连通性测试。
Future<void> showSourceConfigDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SourceConfigDialog(),
  );
}

class _SourceConfigDialog extends StatefulWidget {
  const _SourceConfigDialog();

  @override
  State<_SourceConfigDialog> createState() => _SourceConfigDialogState();
}

class _SourceConfigDialogState extends State<_SourceConfigDialog> {
  late final List<TextEditingController> _controllers;
  late final TextEditingController _baseUrl;
  late final TextEditingController _searchPath;
  late final TextEditingController _playPath;
  late final TextEditingController _searchKeywordKey;
  late final TextEditingController _searchListKey;
  late final TextEditingController _idKey;
  late final TextEditingController _titleKey;
  late final TextEditingController _artistKey;
  late final TextEditingController _albumKey;
  late final TextEditingController _durationKey;
  late final TextEditingController _coverKey;
  late final TextEditingController _playIdParam;
  late final TextEditingController _playUrlKey;

  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final current =
        Get.find<SettingsService>().source.value ??
        const OnlineSourceConfig(baseUrl: '');
    _baseUrl = TextEditingController(text: current.baseUrl);
    _searchPath = TextEditingController(text: current.searchPath);
    _playPath = TextEditingController(text: current.playPath);
    _searchKeywordKey = TextEditingController(text: current.searchKeywordKey);
    _searchListKey = TextEditingController(text: current.searchListKey);
    _idKey = TextEditingController(text: current.idKey);
    _titleKey = TextEditingController(text: current.titleKey);
    _artistKey = TextEditingController(text: current.artistKey);
    _albumKey = TextEditingController(text: current.albumKey);
    _durationKey = TextEditingController(text: current.durationKey);
    _coverKey = TextEditingController(text: current.coverKey);
    _playIdParam = TextEditingController(text: current.playIdParam);
    _playUrlKey = TextEditingController(text: current.playUrlKey);
    _controllers = [
      _baseUrl,
      _searchPath,
      _playPath,
      _searchKeywordKey,
      _searchListKey,
      _idKey,
      _titleKey,
      _artistKey,
      _albumKey,
      _durationKey,
      _coverKey,
      _playIdParam,
      _playUrlKey,
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  OnlineSourceConfig get _config => OnlineSourceConfig(
        baseUrl: _baseUrl.text.trim(),
        searchPath: _searchPath.text.trim(),
        playPath: _playPath.text.trim(),
        searchKeywordKey: _searchKeywordKey.text.trim(),
        searchListKey: _searchListKey.text.trim(),
        idKey: _idKey.text.trim(),
        titleKey: _titleKey.text.trim(),
        artistKey: _artistKey.text.trim(),
        albumKey: _albumKey.text.trim(),
        durationKey: _durationKey.text.trim(),
        coverKey: _coverKey.text.trim(),
        playIdParam: _playIdParam.text.trim(),
        playUrlKey: _playUrlKey.text.trim(),
      );

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      await Get.find<OnlineSourceService>().testConnection(_config);
      Get.snackbar('连接成功', '网络源可用');
    } on AppException catch (e) {
      Get.snackbar('连接失败', e.message);
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save() async {
    final config = _config;
    final url = config.baseUrl;
    if (url.isEmpty || !url.startsWith('http')) {
      Get.snackbar('无法保存', 'API 地址需以 http(s):// 开头');
      return;
    }
    await Get.find<SettingsService>().setSource(config);
    if (!mounted) return;
    Navigator.of(context).pop();
    Get.snackbar('已保存', '网络源配置已更新');
  }

  Future<void> _clear() async {
    await Get.find<SettingsService>().setSource(null);
    if (!mounted) return;
    Navigator.of(context).pop();
    Get.snackbar('已清除', '网络源配置已清除');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('网络音乐源配置'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Field(controller: _baseUrl, label: 'API 地址', hint: 'https://example.com/api'),
              _Field(controller: _searchPath, label: '搜索接口路径', hint: '/search'),
              _Field(controller: _playPath, label: '取播放地址路径', hint: '/song/url'),
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('高级：请求参数与字段映射'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  _Field(controller: _searchKeywordKey, label: '搜索关键词参数名'),
                  _Field(controller: _playIdParam, label: '取地址歌曲 id 参数名'),
                  _Field(controller: _searchListKey, label: '搜索结果列表字段（支持 a.b 嵌套）'),
                  _Field(controller: _idKey, label: '歌曲 id 字段'),
                  _Field(controller: _titleKey, label: '标题字段'),
                  _Field(controller: _artistKey, label: '歌手字段'),
                  _Field(controller: _albumKey, label: '专辑字段'),
                  _Field(controller: _durationKey, label: '时长字段（秒）'),
                  _Field(controller: _coverKey, label: '封面字段'),
                  _Field(controller: _playUrlKey, label: '播放地址字段'),
                ],
              ),
              TextButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
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
        TextButton(onPressed: _clear, child: const Text('清除配置')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
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
