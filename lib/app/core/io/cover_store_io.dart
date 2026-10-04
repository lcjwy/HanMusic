import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 把图片复制进应用专属 covers 目录，返回新路径；失败返回 null。
///
/// [fileName] 需含扩展名；同名旧文件会被覆盖。自定义歌单封面、
/// 导入的图片等用户资源统一存放在此，卸载应用即随之清理。
Future<String?> copyIntoAppCovers(String sourcePath, String fileName) async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final coversDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}covers',
    );
    await coversDir.create(recursive: true);
    final dest = File('${coversDir.path}${Platform.pathSeparator}$fileName');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  } on Exception {
    return null;
  }
}
