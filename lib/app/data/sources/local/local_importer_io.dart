import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:path_provider/path_provider.dart';

/// 递归扫描目录下全部受支持的音频文件。扫描在后台 isolate 执行，
/// 大目录遍历不再阻塞 UI。
Future<List<String>> scanAudioFiles(String dirPath) {
  return Isolate.run(() => _scanAudioFilesSync(dirPath));
}

List<String> _scanAudioFilesSync(String dirPath) {
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

/// 单个文件的标签解析结果（后台 isolate → 主 isolate 的传递载荷）。
typedef _FileMetadata = ({
  String? title,
  String? artist,
  String? album,
  Duration? duration,
  ({Uint8List bytes, String mimetype})? picture,
});

/// 读取音频文件元数据生成 [Song]：标签缺失时以文件名兜底，
/// 内嵌封面落盘到应用数据目录；读取过程失败不阻断导入。
Future<Song> songFromFile(String path) async {
  _FileMetadata metadata;
  try {
    // 标签解析含整文件读取，放后台 isolate；平台通道仅主 isolate 可用，
    // 封面落盘因此留在调用方
    metadata = await Isolate.run(() => _readMetadataSync(path));
  } on Object {
    // 元数据读取失败（含 Error 级异常）：以文件名兜底，不中断整批导入
    return Song.fromLocalFile(path: path);
  }
  var song = Song.fromLocalFile(
    path: path,
    title: metadata.title,
    artist: metadata.artist,
    album: metadata.album,
    duration: metadata.duration,
  );
  final picture = metadata.picture;
  if (picture != null) {
    final coverPath = await _saveCover(picture.bytes, picture.mimetype, song.id);
    if (coverPath != null) {
      song = song.copyWith(coverUrl: coverPath);
    }
  }
  return song;
}

/// 仅在后台 isolate 中执行：读文件并解析标签与内嵌封面。
_FileMetadata _readMetadataSync(String path) {
  final metadata = readMetadata(File(path), getImage: true);
  final pictures = metadata.pictures;
  return (
    title: metadata.title,
    artist: metadata.artist,
    album: metadata.album,
    duration: metadata.duration,
    picture: pictures.isEmpty
        ? null
        : (bytes: pictures.first.bytes, mimetype: pictures.first.mimetype),
  );
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
