import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/ai_settings.dart';
import 'package:han_music/app/services/ai_service.dart';
import 'package:han_music/app/services/settings_service.dart';

/// AI 服务配置对话框：选择供应商（Key 按供应商各自保留）与模型、
/// 填写 API Key（保存走系统安全区）、测试连接。
Future<void> showAiConfigDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AiConfigDialog(),
  );
}

class _AiConfigDialog extends StatefulWidget {
  const _AiConfigDialog();

  @override
  State<_AiConfigDialog> createState() => _AiConfigDialogState();
}

class _AiConfigDialogState extends State<_AiConfigDialog> {
  late AiProvider _provider;
  late String _model;
  bool _customModel = false;
  bool _obscure = true;
  bool _loadingKey = true;
  bool _saving = false;
  bool _testing = false;

  final _keyController = TextEditingController();
  final _customModelController = TextEditingController();

  AiService get _ai => Get.find<AiService>();
  SettingsService get _settings => Get.find<SettingsService>();

  @override
  void initState() {
    super.initState();
    final config = _settings.ai.value;
    _provider = config?.provider ?? AiProvider.stepfun;
    _model = config?.model ?? _provider.presets.first;
    _customModel = !_provider.presets.contains(_model);
    if (_customModel) _customModelController.text = _model;
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _ai.apiKey(_provider);
    if (!mounted) return;
    setState(() {
      _keyController.text = key ?? '';
      _loadingKey = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  void _switchProvider(AiProvider provider) {
    if (provider == _provider) return;
    setState(() {
      _provider = provider;
      _model = provider.presets.first;
      _customModel = false;
    });
    _loadKey();
  }

  AiConfig get _config => AiConfig(
        provider: _provider,
        model: _customModel
            ? _customModelController.text.trim()
            : _model,
      );

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      Get.snackbar('无法测试', '请先填写 API Key');
      return;
    }
    setState(() => _testing = true);
    try {
      await _ai.testConnection(_config, key);
      Get.snackbar('连接成功', '${_provider.label} 可用');
    } on AppException catch (e) {
      Get.snackbar('连接失败', e.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final config = _config;
    if (config.model.isEmpty) {
      Get.snackbar('无法保存', '请填写模型名');
      return;
    }
    setState(() => _saving = true);
    try {
      await _ai.saveApiKey(config.provider, _keyController.text.trim());
      await _settings.setAiConfig(config);
      if (!mounted) return;
      Navigator.of(context).pop();
      Get.snackbar('已保存', 'AI 服务：${config.provider.label} · ${config.model}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    await _ai.saveApiKey(_provider, null);
    await _settings.setAiConfig(null);
    if (!mounted) return;
    Navigator.of(context).pop();
    Get.snackbar('已清除', 'AI 服务配置已清除');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 服务配置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<AiProvider>(
                segments: [
                  for (final provider in AiProvider.values)
                    ButtonSegment(
                      value: provider,
                      label: Text(provider.label),
                    ),
                ],
                selected: {_provider},
                onSelectionChanged: (selection) =>
                    _switchProvider(selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyController,
                obscureText: _obscure,
                enabled: !_loadingKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'API Key（加密存储于系统安全区）',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _customModel ? '__custom__' : _model,
                decoration: const InputDecoration(
                  labelText: '模型',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final preset in _provider.presets)
                    DropdownMenuItem(value: preset, child: Text(preset)),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('自定义…'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  if (value == '__custom__') {
                    _customModel = true;
                  } else {
                    _customModel = false;
                    _model = value ?? _provider.presets.first;
                  }
                }),
              ),
              if (_customModel) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customModelController,
                  decoration: const InputDecoration(
                    labelText: '模型名',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
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
              Text(
                'Key 仅存于系统安全区（Keystore/Keychain/DPAPI），不写入明文；'
                '切换供应商时各自 Key 保留。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
