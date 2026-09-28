import 'dart:io';

/// 本地文件是否存在（IO 平台实现）。
bool localFileExists(String path) => File(path).existsSync();
