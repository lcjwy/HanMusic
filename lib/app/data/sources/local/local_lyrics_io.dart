import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

/// 读取音频文件内嵌歌词原文（USLT/LRC，普通文本或 LRC 格式）。
/// 无歌词或读取失败返回 null，不阻断播放；解析在后台 isolate 执行。
Future<String?> readEmbeddedLyrics(String path) {
  return Isolate.run(() {
    try {
      return readMetadata(File(path), getImage: false).lyrics;
    } on Object {
      return null;
    }
  });
}
