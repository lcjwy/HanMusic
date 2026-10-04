import 'package:han_music/app/core/storage/secret_store.dart';

/// Web 端实现：无系统安全区，Key 仅会话级内存保存（本次运行有效），
/// 不提供任何明文落盘兜底（见需求文档安全要求）。
class SecureSecretStore implements SecretStore {
  final InMemorySecretStore _memory = InMemorySecretStore();

  @override
  Future<String?> read(String key) => _memory.read(key);

  @override
  Future<void> write(String key, String value) => _memory.write(key, value);

  @override
  Future<void> delete(String key) => _memory.delete(key);
}
