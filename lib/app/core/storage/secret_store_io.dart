import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:han_music/app/core/storage/secret_store.dart';

/// 系统安全区实现：Android Keystore / iOS·macOS Keychain /
/// Windows DPAPI / Linux libsecret，由 flutter_secure_storage 适配
/// （11.x 默认启用 Android 加密存储）。
class SecureSecretStore implements SecretStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) {
    try {
      return _storage.read(key: key);
    } on Exception {
      return Future.value(null);
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
