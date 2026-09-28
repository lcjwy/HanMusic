import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/utils/hash.dart';
import 'package:han_music/app/data/models/song.dart';

void main() {
  final song = Song(
    id: 'local-abc123',
    title: '晴天',
    artist: '周杰伦',
    album: '叶惠美',
    duration: const Duration(milliseconds: 269000),
    source: SongSource.local,
    pathOrUrl: '/music/晴天.mp3',
    addedAt: DateTime(2026, 9, 28),
  );

  group('Song JSON 序列化', () {
    Song roundtrip(Song s) => Song.fromJson(
          (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, dynamic>(),
        );

    test('toJson → fromJson 往返一致', () {
      final restored = roundtrip(song);
      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.duration, song.duration);
      expect(restored.source, song.source);
      expect(restored.pathOrUrl, song.pathOrUrl);
      expect(restored.addedAt, song.addedAt);
    });

    test('字段缺失或损坏时使用安全默认值', () {
      final restored = Song.fromJson(const {});
      expect(restored.title, '未知标题');
      expect(restored.artist, '未知歌手');
      expect(restored.album, '未知专辑');
      expect(restored.source, SongSource.local);
      expect(restored.duration, isNull);
      expect(restored.missing, isFalse);
    });

    test('相等性仅由 id 决定', () {
      expect(song == song.copyWith(missing: true), isTrue);
      expect(song.hashCode, song.copyWith(missing: true).hashCode);
      expect(
        song ==
            Song(
              id: 'other',
              title: 'x',
              pathOrUrl: 'y',
              addedAt: DateTime(2026),
            ),
        isFalse,
      );
    });
  });

  group('Song.fromLocalFile', () {
    test('id 基于路径稳定哈希，元数据以文件名兜底（去扩展名）', () {
      final a = Song.fromLocalFile(path: 'E:/music/晴天.mp3');
      final b = Song.fromLocalFile(path: 'E:/music/晴天.mp3');
      expect(a.id, startsWith('local-'));
      expect(a.id, b.id);
      expect(a.title, '晴天');
      expect(a.artist, '未知歌手');
      expect(a.source, SongSource.local);
    });

    test('提供的元数据优先于文件名', () {
      final s = Song.fromLocalFile(
        path: 'E:/music/track01.mp3',
        title: '晴天',
        artist: '周杰伦',
      );
      expect(s.title, '晴天');
      expect(s.artist, '周杰伦');
    });
  });

  test('stableHash 对相同输入稳定、不同输入不同', () {
    expect(stableHash('E:/music/a.mp3'), stableHash('E:/music/a.mp3'));
    expect(stableHash('a'), isNot(stableHash('b')));
    expect(stableHash('x'), matches(RegExp(r'^[0-9a-f]{8}$')));
  });
}
