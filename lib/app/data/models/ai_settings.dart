/// AI 供应商：三家内置预设（接口地址与常用模型随 App 内置）。
enum AiProvider {
  stepfun('阶跃星辰', 'https://api.stepfun.com/v1',
      ['step-2-16k', 'step-1-8k', 'step-1v-8k']),
  zhipu('智谱 AI', 'https://open.bigmodel.cn/api/paas/v4',
      ['glm-4-flash', 'glm-4-air', 'glm-4-plus']),
  deepseek('DeepSeek', 'https://api.deepseek.com/v1',
      ['deepseek-chat', 'deepseek-reasoner']);

  const AiProvider(this.label, this.baseUrl, this.presets);

  final String label;
  final String baseUrl;
  final List<String> presets;

  static AiProvider? ofName(String? name) {
    for (final provider in values) {
      if (provider.name == name) return provider;
    }
    return null;
  }
}

/// AI 服务配置（本期能力仅歌词获取）。API Key 不在本模型内——
/// 只经 SecretStore（系统安全区）按供应商存取，禁止随配置落盘。
class AiConfig {
  const AiConfig({required this.provider, required this.model});

  final AiProvider provider;
  final String model;

  Map<String, dynamic> toJson() => {'provider': provider.name, 'model': model};

  /// 字段异常时返回 null（调用方按未配置处理），不阻断设置加载。
  static AiConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final provider = AiProvider.ofName(raw['provider']?.toString());
    final model = raw['model'];
    if (provider == null || model is! String || model.trim().isEmpty) {
      return null;
    }
    return AiConfig(provider: provider, model: model.trim());
  }
}
