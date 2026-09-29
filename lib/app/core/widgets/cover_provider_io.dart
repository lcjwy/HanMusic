import 'dart:io';

import 'package:flutter/painting.dart';

/// 封面存在性检查结果缓存：长列表滚动时避免对同一文件反复做磁盘 IO。
/// 条目极小；封面文件在会话内基本不变，无需失效机制，仅设上限防异常增长。
final _providerCache = <String, ImageProvider?>{};

/// 本地封面文件 → ImageProvider；文件不存在返回 null（由调用方显示占位）。
ImageProvider? localCoverProvider(String path) {
  if (_providerCache.containsKey(path)) {
    return _providerCache[path];
  }
  final provider = File(path).existsSync() ? FileImage(File(path)) : null;
  if (_providerCache.length >= 2048) {
    _providerCache.clear();
  }
  _providerCache[path] = provider;
  return provider;
}
