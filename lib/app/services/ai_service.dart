import 'package:get/get.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/core/storage/secret_store.dart';
import 'package:han_music/app/data/models/ai_settings.dart';
import 'package:han_music/app/data/sources/remote/ai_client.dart';
import 'package:han_music/app/services/settings_service.dart';

/// 供应商客户端构造：按配置的 baseUrl/model 与本次请求的 Key 创建，
/// 用毕即关（与网络源适配器同一生命周期约定）。
typedef AiClientFactory = AiClient Function(AiConfig config, String apiKey);

/// AI 服务（F10）：按供应商管理 API Key（仅存系统安全区），
/// 提供连通性测试与歌词获取。本期能力仅「歌词获取」。
class AiService extends GetxService {
  AiService(this._secret, {AiClientFactory? clientFactory})
      : _clientFactory = clientFactory ?? defaultClientFactory;

  final SecretStore _secret;
  final AiClientFactory _clientFactory;

  static AiClient defaultClientFactory(AiConfig config, String apiKey) =>
      AiClient(
        baseUrl: config.provider.baseUrl,
        apiKey: apiKey,
        model: config.model,
      );

  static const _keyPrefix = 'ai_key:';

  /// 已就绪 Key 的供应商集合（init/save 时同步维护，
  /// 供歌词链路同步判定 AI 是否可用）。
  final _keysReady = <AiProvider>{};

  /// 启动时预读各供应商 Key 是否存在。
  Future<void> init() async {
    for (final provider in AiProvider.values) {
      final key = await apiKey(provider);
      if (key != null && key.isNotEmpty) _keysReady.add(provider);
    }
  }

  /// 指定供应商是否已填 Key（同步判定）。
  bool hasKey(AiProvider provider) => _keysReady.contains(provider);

  String _keyOf(AiProvider provider) => '$_keyPrefix${provider.name}';

  /// 读取指定供应商的 API Key（未存返回 null）。
  Future<String?> apiKey(AiProvider provider) => _secret.read(_keyOf(provider));

  /// Key 脱敏展示：前 4 后 4，中间以 **** 代替。
  static String maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  /// 保存/清除指定供应商的 API Key（空串即清除）。
  /// 切换供应商时各自 Key 保留，便于来回切换。
  Future<void> saveApiKey(AiProvider provider, String? key) async {
    final trimmed = key?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _secret.delete(_keyOf(provider));
      _keysReady.remove(provider);
    } else {
      await _secret.write(_keyOf(provider), trimmed);
      _keysReady.add(provider);
    }
  }

  /// 连通性测试：一次最小对话请求；失败抛 [AppException]（区分提示）。
  Future<void> testConnection(AiConfig config, String apiKey) async {
    final client = _clientFactory(config, apiKey);
    try {
      await client.chat(system: 'You are a connectivity test.', user: 'ping');
    } finally {
      client.close();
    }
  }

  /// 请求歌词：提示词约束只返回歌词本体，优先 LRC 带时间戳格式。
  /// 未配置/未填 Key 或 AI 拒绝输出时抛 [AppException]。
  Future<String> fetchLyrics({
    required String title,
    required String artist,
    String? album,
  }) async {
    final config = Get.find<SettingsService>().ai.value;
    if (config == null) {
      throw const AppException('尚未配置 AI 服务');
    }
    final key = await apiKey(config.provider);
    if (key == null || key.isEmpty) {
      throw const AppException('尚未填写 AI API Key');
    }
    final client = _clientFactory(config, key);
    try {
      return await client.chat(
        system: '你是歌词助手。只输出歌词本体，不要任何解释、开场白、标注或重复歌曲信息。'
            '优先输出带 [mm:ss.xx] 时间戳的 LRC 格式歌词；无法确定时间轴时输出纯文本逐行歌词。',
        user: '请提供歌曲《$title》'
            '${artist.isEmpty ? '' : ' 演唱者：$artist'}'
            '${album == null || album.isEmpty ? '' : ' 专辑：$album'}'
            ' 的歌词。',
      );
    } finally {
      client.close();
    }
  }
}
