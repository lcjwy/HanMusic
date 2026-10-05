import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/lyrics_service.dart';

void main() {
  test('manual lyrics survive an older in-flight AI request', () async {
    final response = Completer<String>();
    final started = Completer<void>();
    final service = LyricsService(
      MemoryStore(),
      readEmbedded: (_) async => null,
      readSourceLyrics: (_) async => null,
      isAiConfigured: () => true,
      fetchAiLyrics: (_) {
        started.complete();
        return response.future;
      },
    );
    final song = Song.fromLocalFile(path: '/a.mp3', title: 'A');
    final pending = service.resolve(song);
    await started.future;
    await service.saveManual(song, '[00:01.00]manual');
    response.complete('[00:01.00]AI');
    await pending;
    final result = await service.resolve(song);
    expect(result!.manual, isTrue);
    expect(result.document.lines.single.text, 'manual');
  });

  test('迟到的网络源歌词保留手动歌词，且请求返回手动结果', () async {
    final response = Completer<String>();
    final started = Completer<void>();
    final service = LyricsService(
      MemoryStore(),
      readEmbedded: (_) async => null,
      readSourceLyrics: (_) {
        started.complete();
        return response.future;
      },
      isAiConfigured: () => false,
      fetchAiLyrics: (_) async => '',
    );
    final song = Song.fromLocalFile(path: '/a.mp3', title: 'A');
    final pending = service.resolve(song);
    await started.future;
    await service.saveManual(song, '[00:01.00]manual');
    response.complete('[00:01.00]source');
    final result = await pending;
    expect(result!.manual, isTrue);
    expect(result.document.lines.single.text, 'manual');
  });

  test('两首歌曲并发获取歌词不会丢失另一首缓存', () async {
    final response = {'A': Completer<String>(), 'B': Completer<String>()};
    final started = Completer<void>();
    var calls = 0;
    final service = LyricsService(
      MemoryStore(),
      readEmbedded: (_) async => null,
      readSourceLyrics: (song) {
        if (++calls == 2) started.complete();
        return response[song.title]!.future;
      },
      isAiConfigured: () => false,
      fetchAiLyrics: (_) async => '',
    );
    final a = Song.fromLocalFile(path: '/a.mp3', title: 'A');
    final b = Song.fromLocalFile(path: '/b.mp3', title: 'B');
    final pending = [service.resolve(a), service.resolve(b)];
    await started.future;
    response['A']!.complete('[00:01.00]A');
    response['B']!.complete('[00:01.00]B');
    await Future.wait(pending);
    expect(service.cacheCount.value, 2);
    expect((await service.resolve(a))!.document.lines.single.text, 'A');
    expect((await service.resolve(b))!.document.lines.single.text, 'B');
    expect(calls, 2);
  });
}
