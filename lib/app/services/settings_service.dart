import 'dart:convert';

import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/app_settings.dart';

/// 全局设置：主题、网络源配置、播放失败自动跳过。变更即持久化。
class SettingsService extends GetxService {
  SettingsService(this._store);

  final KeyValueStore _store;

  final themeMode = AppThemeMode.system.obs;
  final source = Rxn<OnlineSourceConfig>();
  final autoSkipOnFail = true.obs;

  bool get hasSource => source.value != null;

  /// 启动加载；配置损坏时静默回退默认值。
  Future<void> load() async {
    try {
      final raw = _store.read<String>(AppConstants.keySettings);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      themeMode.value = AppThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => AppThemeMode.system,
      );
      source.value = json['source'] is Map
          ? OnlineSourceConfig.fromJson(
              (json['source'] as Map).cast<String, dynamic>(),
            )
          : null;
      autoSkipOnFail.value = json['autoSkipOnFail'] is bool
          ? json['autoSkipOnFail'] as bool
          : true;
    } on FormatException {
      // 配置损坏时保持默认值
    } on TypeError {
      // 结构/字段类型损坏同理
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    themeMode.value = mode;
    await _persist();
  }

  Future<void> setSource(OnlineSourceConfig? config) async {
    source.value = config;
    await _persist();
  }

  Future<void> setAutoSkipOnFail(bool value) async {
    autoSkipOnFail.value = value;
    await _persist();
  }

  Future<void> _persist() async {
    final json = {
      'themeMode': themeMode.value.name,
      'source': source.value?.toJson(),
      'autoSkipOnFail': autoSkipOnFail.value,
    };
    await _store.write(AppConstants.keySettings, jsonEncode(json));
  }
}
