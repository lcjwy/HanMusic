import 'dart:io';

import 'package:flutter/painting.dart';

/// 本地封面文件 → ImageProvider；文件不存在返回 null（由调用方显示占位）。
ImageProvider? localCoverProvider(String path) {
  final file = File(path);
  return file.existsSync() ? FileImage(file) : null;
}
