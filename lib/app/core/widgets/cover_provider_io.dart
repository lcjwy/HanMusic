import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:han_music/app/core/constants/app_constants.dart';

/// 封面存在性检查结果缓存：长列表滚动时避免对同一文件反复做磁盘 IO。
/// 条目极小；封面文件在会话内基本不变，无需失效机制。
/// Dart 的 Map 字面量即 LinkedHashMap，按插入/重插顺序维护，
/// 超限时淘汰最久未用的条目——大曲库下整体 clear 会让已缓存
/// 条目反复回源 stat。
final _providerCache = <String, ImageProvider?>{};

/// 本地封面文件 → ImageProvider；文件不存在返回 null（由调用方显示占位）。
ImageProvider? localCoverProvider(String path) {
  if (_providerCache.containsKey(path)) {
    // null 值也是有效缓存（文件不存在的负面缓存），重新插入刷新访问序
    final provider = _providerCache.remove(path);
    _providerCache[path] = provider;
    return provider;
  }
  final provider = File(path).existsSync() ? FileImage(File(path)) : null;
  while (_providerCache.length >= AppConstants.coverCacheLimit) {
    _providerCache.remove(_providerCache.keys.first);
  }
  _providerCache[path] = provider;
  return provider;
}
