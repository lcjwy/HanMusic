import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/bili/bili_cache_scanner.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bili_cache_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Directory writePage(
    String relativePageDir, {
    Object? entryJson,
    List<int> audioBytes = const [1, 2, 3],
    List<int>? alternateAudioBytes,
  }) {
    final pageDir = Directory('${root.path}/$relativePageDir')
      ..createSync(recursive: true);
    if (entryJson != null) {
      File('${pageDir.path}/entry.json')
          .writeAsStringSync(jsonEncode(entryJson));
    }
    if (audioBytes.isNotEmpty) {
      Directory('${pageDir.path}/64').createSync(recursive: true);
      File('${pageDir.path}/64/audio.m4s').writeAsBytesSync(audioBytes);
    }
    if (alternateAudioBytes != null) {
      Directory('${pageDir.path}/30280').createSync(recursive: true);
      File('${pageDir.path}/30280/audio.m4s').writeAsBytesSync(alternateAudioBytes);
    }
    return pageDir;
  }

  test('扫描标准缓存结构：解析标题/UP主/合集/时长，取最大音轨', () async {
    writePage(
      '9/合集A/001',
      entryJson: {
        'title': '视频标题',
        'owner_name': 'UP主小张',
        'page_data': {'part': '第一集', 'duration': 125},
      },
      audioBytes: List.filled(10, 1),
      alternateAudioBytes: List.filled(20, 1),
    );

    final entries = await scanBiliCache(root.path);
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.importable, isTrue);
    expect(entry.title, '第一集');
    expect(entry.artist, 'UP主小张');
    expect(entry.album, '合集A');
    expect(entry.duration, const Duration(seconds: 125));
    expect(entry.audioPath.endsWith('audio.m4s'), isTrue);
    // 30280 目录音轨更大，应被选中
    expect(entry.audioPath.contains('30280'), isTrue);

    final song = entry.toSong()!;
    expect(song.id, startsWith('bili-'));
    expect(song.source, SongSource.bili);
    expect(song.pathOrUrl, entry.audioPath);
  });

  test('分P名缺失回退视频标题，owner 缺失回退未知歌手', () async {
    writePage('9/合集B/002', entryJson: {
      'title': '只有标题',
      'page_data': {'duration': 10},
    });
    final entries = await scanBiliCache(root.path);
    expect(entries.single.title, '只有标题');
    expect(entries.single.artist, '未知歌手');
  });

  test('缺 audio.m4s → 标记无法导入，不阻断其余条目', () async {
    writePage('9/合集C/003',
        entryJson: {'title': '有json无音轨'}, audioBytes: const []);
    writePage('9/合集C/004', entryJson: {
      'title': '正常分P',
      'owner_name': 'UP主',
      'page_data': {'part': 'P2', 'duration': 30},
    });
    final entries = await scanBiliCache(root.path);
    expect(entries, hasLength(2));
    final broken = entries.singleWhere((e) => !e.importable);
    expect(broken.problem, '未找到 audio.m4s 音轨');
    expect(broken.toSong(), isNull);
    expect(entries.singleWhere((e) => e.importable).title, 'P2');
  });

  test('entry.json 损坏 → 标记解析失败', () async {
    final pageDir = Directory('${root.path}/9/坏json/005')
      ..createSync(recursive: true);
    File('${pageDir.path}/entry.json').writeAsStringSync('{broken');
    Directory('${pageDir.path}/64').createSync(recursive: true);
    File('${pageDir.path}/64/audio.m4s').writeAsBytesSync([1]);

    final entries = await scanBiliCache(root.path);
    expect(entries.single.problem, 'entry.json 解析失败');
    // 音轨存在仍记录路径，供人工排查
    expect(entries.single.audioPath.isNotEmpty, isTrue);
  });

  test('空目录与不存在的根目录返回空', () async {
    expect(await scanBiliCache(root.path), isEmpty);
    expect(await scanBiliCache('${root.path}/not_exist'), isEmpty);
  });
}
