import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/services/settings_service.dart';

void main() {
  test('默认值：跟随系统、未配置源、失败自动跳过开启', () async {
    final service = SettingsService(MemoryStore());
    await service.load();

    expect(service.themeMode.value, AppThemeMode.system);
    expect(service.source.value, isNull);
    expect(service.hasSource, isFalse);
    expect(service.autoSkipOnFail.value, isTrue);
  });

  test('修改即持久化，可被新实例恢复', () async {
    final store = MemoryStore();
    final service = SettingsService(store);
    await service.load();

    const config = OnlineSourceConfig(baseUrl: 'https://example.com/api');
    await service.setThemeMode(AppThemeMode.dark);
    await service.setSource(config);
    await service.setAutoSkipOnFail(false);

    final restored = SettingsService(store);
    await restored.load();

    expect(restored.themeMode.value, AppThemeMode.dark);
    expect(restored.source.value?.baseUrl, 'https://example.com/api');
    expect(restored.autoSkipOnFail.value, isFalse);
  });

  test('清除网络源后恢复未配置状态', () async {
    final store = MemoryStore();
    final service = SettingsService(store);
    await service.load();
    await service.setSource(const OnlineSourceConfig(baseUrl: 'https://a.com'));

    await service.setSource(null);
    expect(service.hasSource, isFalse);

    final restored = SettingsService(store);
    await restored.load();
    expect(restored.hasSource, isFalse);
  });

  test('存储内容损坏时回退默认值', () async {
    final store = MemoryStore();
    await store.write('settings', '{not valid json');
    final service = SettingsService(store);
    await service.load();

    expect(service.themeMode.value, AppThemeMode.system);
    expect(service.hasSource, isFalse);
  });
}
