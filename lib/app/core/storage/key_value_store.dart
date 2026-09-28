import 'package:get_storage/get_storage.dart';

/// 键值存储抽象：隔离具体持久化实现，业务层不直接接触 GetStorage。
abstract class KeyValueStore {
  /// 初始化存储（应用启动时调用一次）。
  Future<void> init();

  T? read<T>(String key);

  Future<void> write(String key, dynamic value);

  Future<void> remove(String key);
}

/// 基于 GetStorage 的实现（应用运行时使用）。
class GetStorageStore implements KeyValueStore {
  GetStorageStore({this.container = 'han_music'});

  final String container;

  late final GetStorage _box;

  @override
  Future<void> init() async {
    await GetStorage.init(container);
    _box = GetStorage(container);
  }

  @override
  T? read<T>(String key) => _box.read<T>(key);

  @override
  Future<void> write(String key, dynamic value) => _box.write(key, value);

  @override
  Future<void> remove(String key) => _box.remove(key);
}

/// 内存实现：仅用于单元测试。
class MemoryStore implements KeyValueStore {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  T? read<T>(String key) => _data[key] as T?;

  @override
  Future<void> write(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }
}
