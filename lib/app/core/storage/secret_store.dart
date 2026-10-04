// 敏感凭据存储抽象：隔离具体安全区实现，Web 端编译走会话级内存实现。
export 'secret_store_io.dart' if (dart.library.js_interop) 'secret_store_stub.dart';

/// 密钥级安全存储（区别于 [KeyValueStore]）：仅存 API Key 等敏感凭据。
/// 实现必须落到系统安全区（Keystore/Keychain/DPAPI/libsecret），
/// 禁止明文写入首选项、普通文件与日志。
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// 内存实现：测试用，以及 Web 端"会话级保存"语义（本次运行有效）。
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
