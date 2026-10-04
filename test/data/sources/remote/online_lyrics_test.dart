import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/remote/online_source_adapter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

Song onlineSong() => Song(
      id: 'online-42',
      title: '测试歌',
      pathOrUrl: '',
      addedAt: DateTime(2026),
      source: SongSource.online,
    );

void main() {
  group('OnlineSourceAdapter.resolveLyrics', () {
    test('未配置歌词接口路径返回 null，不发请求', () async {
      var called = false;
      final adapter = OnlineSourceAdapter(
        const OnlineSourceConfig(baseUrl: 'https://example.com'),
        client: MockClient((_) async {
          called = true;
          return jsonResponse({});
        }),
      );
      expect(await adapter.resolveLyrics(onlineSong()), isNull);
      expect(called, isFalse);
    });

    test('按配置参数与字段获取歌词内容', () async {
      Uri? requested;
      final adapter = OnlineSourceAdapter(
        const OnlineSourceConfig(
          baseUrl: 'https://example.com/api/',
          lyricsPath: '/lyric',
          lyricsIdParam: 'mid',
          lyricsKey: 'data.lrc',
        ),
        client: MockClient((request) async {
          requested = request.url;
          return jsonResponse({
            'data': {'lrc': '[00:01.00]你好'},
          });
        }),
      );
      final lyric = await adapter.resolveLyrics(onlineSong());
      expect(lyric, '[00:01.00]你好');
      expect(requested!.toString(), 'https://example.com/api/lyric?mid=42');
    });

    test('响应缺歌词字段或为空返回 null', () async {
      final adapter = OnlineSourceAdapter(
        const OnlineSourceConfig(
          baseUrl: 'https://example.com',
          lyricsPath: '/lyric',
        ),
        client: MockClient((_) async => jsonResponse({'other': 1})),
      );
      expect(await adapter.resolveLyrics(onlineSong()), isNull);

      final emptyAdapter = OnlineSourceAdapter(
        const OnlineSourceConfig(
          baseUrl: 'https://example.com',
          lyricsPath: '/lyric',
        ),
        client: MockClient((_) async => jsonResponse({'lyric': '  '})),
      );
      expect(await emptyAdapter.resolveLyrics(onlineSong()), isNull);
    });

    test('请求失败转译为 AppException（由服务层降级吞掉）', () async {
      final adapter = OnlineSourceAdapter(
        const OnlineSourceConfig(
          baseUrl: 'https://example.com',
          lyricsPath: '/lyric',
        ),
        client: MockClient((_) async => throw Exception('boom')),
      );
      await expectLater(
        adapter.resolveLyrics(onlineSong()),
        throwsA(isA<AppException>()),
      );
    });
  });
}
