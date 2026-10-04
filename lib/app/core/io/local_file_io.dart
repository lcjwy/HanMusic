import 'dart:io';

/// 本地文件是否存在（IO 平台实现）。
bool localFileExists(String path) => File(path).existsSync();

/// 删除本地文件（IO 平台实现）。文件不存在或删除失败时静默忽略，
/// 清理类缓存文件不应阻断业务流程。
void localFileDelete(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  } on FileSystemException {
    // 忽略：文件可能已被外部清理或被占用
  }
}
