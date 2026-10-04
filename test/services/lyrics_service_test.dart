import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/lyrics_service.dart';

void main() {
  late MemoryStore store;
  late LyricsService service;

  var embeddedCalls = 0;
  var sourceCalls = 0;
  var aiCalls = 0;

  Song song(String title, {String source = '/a.mp3'}) =>
      Song.fromLocalFile(path: source, title: title, artist: '歌手A');

  LyricsService build({
    String? Function(String path)? embedded,
    String? sourceLyric,
    Object? aiResult, // String 成功 / AppException 失败 / null 未配置
  }) =>
      LyricsService(
        store,
        readEmbedded: (path) async {
          embeddedCalls++;
          return embedded?.call(path);
        },
        readSourceLyrics: (_) async {
          sourceCalls++;
          return sourceLyric;
        },
        isAiConfigured: () => aiResult != null,
        fetchAiLyrics: (_) async {
          aiCalls++;
          final result = aiResult;
          if (result is AppException) throw result;
          return result as String;
        },
      );

  setUp(() {
    store = MemoryStore();
    embeddedCalls = 0;
    sourceCalls = 0;
    aiCalls = 0;
  });

  test('本地歌曲优先读内嵌歌词，命中不请求网络源与 AI', () async {
    service = build(embedded: (_) => '[00:01.00]内嵌');
    final result = await service.resolve(song('内嵌歌'));
    expect(result, isNotNull);
    expect(result!.fromAi, isFalse);
    expect(result.document.lines.single.text, '内嵌');
    expect(embeddedCalls, 1);
    expect(sourceCalls, 0);
    expect(aiCalls, 0);
  });

  test('缓存命中直接返回且离线可用；forceRefresh 重新走链路', () async {
    service = build(sourceLyric: '[00:02.00]源歌词');
    final song = Song(
      id: 'online-1',
      title: '在线歌',
      pathOrUrl: '',
      addedAt: DateTime(2026),
      source: SongSource.online,
    );
    await service.resolve(song);
    expect(service.cacheCount.value, 1);

    // 二次解析：全链路零调用
    final again = await service.resolve(song);
    expect(again!.document.lines.single.text, '源歌词');
    expect(sourceCalls, 1);

    final refreshed = await service.resolve(song, forceRefresh: true);
    expect(refreshed!.document.lines.single.text, '源歌词');
    expect(sourceCalls, 2);
    expect(service.cacheCount.value, 1);
  });

  test('AI 结果写入缓存并标注来源；AI 失败静默返回 null', () async {
    service = build(aiResult: '[00:03.00]AI歌词');
    final result = await service.resolve(song('AI歌'));
    expect(result!.fromAi, isTrue);
    expect(aiCalls, 1);

    // 再次播放命中缓存，不重复请求
    await service.resolve(song('AI歌'));
    expect(aiCalls, 1);

    final failing = build(aiResult: const AppException('余额不足'));
    expect(await failing.resolve(song('失败歌')), isNull);
  });

  test('手动粘贴优先级最高：不被 AI 覆盖、forceRefresh 保留', () async {
    service = build(aiResult: '[00:09.00]AI新词');
    final target = song('手动歌');
    await service.saveManual(target, '[00:01.00]手写词');

    final manual = await service.resolve(target, forceRefresh: true);
    expect(manual!.manual, isTrue);
    expect(manual.document.lines.single.text, '手写词');
    expect(aiCalls, 0);
  });

  test('清空歌词缓存', () async {
    service = build(sourceLyric: '[00:02.00]词');
    await service.resolve(song('清空歌'));
    expect(service.cacheCount.value, 1);

    await service.clearCache();
    expect(service.cacheCount.value, 0);
    expect(await service.resolve(song('清空歌')), isNotNull); // 重新获取
    expect(sourceCalls, 2);
  });
}
