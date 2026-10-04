import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:han_music/app/data/models/bili_cache.dart';
import 'package:han_music/app/data/models/song.dart';

/// 扫描 B站离线缓存根目录（Android 端 download/），解析每个分P的
/// entry.json 与 audio.m4s。整个遍历在后台 isolate 执行，不阻塞 UI。
///
/// 不同 B站版本的 entry.json 字段存在差异，解析逐字段容错：
/// 标题=分P名→视频标题→目录名，专辑=合集目录名，UP主=owner_name。
Future<List<BiliCacheEntry>> scanBiliCache(String rootPath) {
  return Isolate.run(() => _scanSync(rootPath));
}

List<BiliCacheEntry> _scanSync(String rootPath) {
  final root = Directory(rootPath);
  if (!root.existsSync()) return const [];
  final entries = <BiliCacheEntry>[];
  final stack = <Directory>[root];
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        stack.add(entity);
      } else if (entity is File &&
          entity.path.split(Platform.pathSeparator).last == 'entry.json') {
        entries.add(_parseEntry(dir, entity));
      }
    }
  }
  return entries;
}

BiliCacheEntry _parseEntry(Directory pageDir, File entryFile) {
  Map<String, dynamic>? json;
  try {
    final decoded = jsonDecode(entryFile.readAsStringSync());
    if (decoded is Map) json = decoded.cast<String, dynamic>();
  } on Object {
    json = null;
  }

  final pageData = json?['page_data'];
  final part = pageData is Map ? _stringOf(pageData['part']) : null;
  final durationValue = pageData is Map ? pageData['duration'] : null;
  final videoTitle = _stringOf(json?['title']);
  final owner = _stringOf(json?['owner_name']);

  final pageDirName = _lastSegment(pageDir.path);
  final collectionName = _lastSegment(pageDir.parent.path);

  final audio = _findBestAudio(pageDir);
  final title = _nonEmpty(part) ??
      _nonEmpty(videoTitle) ??
      (pageDirName.isNotEmpty ? pageDirName : '未知分P');

  return BiliCacheEntry(
    pageDir: pageDir.path,
    audioPath: audio?.path ?? '',
    title: title,
    artist: _nonEmpty(owner) ?? Song.defaultArtist,
    album: _nonEmpty(collectionName) ??
        _nonEmpty(videoTitle) ??
        'B站缓存',
    duration: durationValue is num && durationValue > 0
        ? Duration(seconds: durationValue.toInt())
        : null,
    problem: json == null
        ? 'entry.json 解析失败'
        : (audio == null ? '未找到 audio.m4s 音轨' : null),
  );
}

/// 分P 目录下按文件体积取最优音轨（不同码率目录各含一份 audio.m4s）。
File? _findBestAudio(Directory pageDir) {
  final matches = <File>[];
  final stack = <Directory>[pageDir];
  var depth = 0;
  while (stack.isNotEmpty && depth <= 3) {
    final next = <Directory>[];
    for (final dir in stack) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory && depth < 3) {
          next.add(entity);
        } else if (entity is File &&
            entity.path.split(Platform.pathSeparator).last == 'audio.m4s') {
          matches.add(entity);
        }
      }
    }
    stack
      ..clear()
      ..addAll(next);
    depth++;
  }
  if (matches.isEmpty) return null;
  File best = matches.first;
  var bestSize = -1;
  for (final file in matches) {
    try {
      final size = file.lengthSync();
      if (size > bestSize) {
        bestSize = size;
        best = file;
      }
    } on FileSystemException {
      continue;
    }
  }
  return best;
}

String? _nonEmpty(String? value) =>
    (value == null || value.trim().isEmpty) ? null : value.trim();

String? _stringOf(Object? value) => value is String ? value : null;

String _lastSegment(String path) {
  final segments = path.split(Platform.pathSeparator).where((s) => s.isNotEmpty);
  return segments.isEmpty ? '' : segments.last;
}
