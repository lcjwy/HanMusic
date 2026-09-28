import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:path_provider/path_provider.dart';

/// 递归扫描目录下全部受支持的音频文件。
List<String> scanAudioFiles(String dirPath) {
  final root = Directory(dirPath);
  if (!root.existsSync()) return const [];
  final result = <String>[];
  final stack = <Directory>[root];
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        stack.add(entity);
      } else if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (AppConstants.audioExtensions.contains(ext)) {
          result.add(entity.path);
        }
      }
    }
  }
  return result;
}

/// 读取音频文件元数据生成 [Song]：标签缺失时以文件名兜底，
/// 内嵌封面落盘到应用数据目录；读取过程失败不阻断导入。
Future<Song> songFromFile(String path) async {
  try {
    final metadata = readMetadata(File(path), getImage: true);
    var song = Song.fromLocalFile(
      path: path,
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      duration: metadata.duration,
    );
    if (metadata.pictures.isNotEmpty) {
      final picture = metadata.pictures.first;
      final coverPath = await _saveCover(
        picture.bytes,
        picture.mimetype,
        song.id,
      );
      if (coverPath != null) {
        song = song.copyWith(coverUrl: coverPath);
      }
    }
    return song;
  } on Exception {
    // 元数据读取失败：以文件名兜底
    return Song.fromLocalFile(path: path);
  }
}

Future<String?> _saveCover(Uint8List bytes, String mimetype, String songId) async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final coversDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}covers',
    );
    await coversDir.create(recursive: true);
    final ext = mimetype.toLowerCase().contains('png') ? 'png' : 'jpg';
    final file = File('${coversDir.path}${Platform.pathSeparator}$songId.$ext');
    await file.writeAsBytes(bytes);
    return file.path;
  } on Exception {
    return null;
  }
}
