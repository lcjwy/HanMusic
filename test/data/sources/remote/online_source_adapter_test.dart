import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/remote/online_source_adapter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// JSON 响应辅助：以 UTF-8 字节构造（http.Response 默认 latin1，中文会抛错）。
http.Response jsonResponse(Object? json, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(json)), status);

OnlineSourceAdapter adapterWith(
  http.Client client, {
  OnlineSourceConfig? config,
}) =>
    OnlineSourceAdapter(
      config ?? const OnlineSourceConfig(baseUrl: 'https://src.example/api'),
      client: client,
    );

void main() {
  group('OnlineSourceAdapter.search', () {
    test('默认字段映射：解析为统一 Song，id 加 online- 前缀', () async {
      final client = MockClient((request) async {
        expect(
          request.url.queryParameters['keywords'],
          '晴天',
          reason: '搜索关键词参数名按配置传递',
        );
        expect(request.url.host, 'src.example');
        expect(request.url.path, '/api/search');
        return jsonResponse({
            'result': [
              {
                'id': 42,
                'name': '晴天',
                'artist': '周杰伦',
                'album': '叶惠美',
                'duration': 269,
                'cover': 'https://img.example/42.jpg',
              },
              {'id': 43, 'name': '七里香'},
            ],
          });
      });

      final songs = await adapterWith(client).search('晴天');

      expect(songs.length, 2);
      expect(songs.first.id, 'online-42');
      expect(songs.first.title, '晴天');
      expect(songs.first.artist, '周杰伦');
      expect(songs.first.album, '叶惠美');
      expect(songs.first.duration, const Duration(seconds: 269));
      expect(songs.first.coverUrl, 'https://img.example/42.jpg');
      expect(songs.first.source, SongSource.online);
      expect(songs.first.pathOrUrl, isEmpty);
      expect(songs.last.artist, Song.defaultArtist);
    });

    test('点路径取嵌套列表与字段', () async {      final client = MockClient(
        (request) async => jsonResponse({
          'data': {
            'songs': [
              {'songId': 'abc', 'songName': '稻香'},
            ],
          },
        }),
      );
      const config = OnlineSourceConfig(
        baseUrl: 'https://x.example',
        searchListKey: 'data.songs',
        idKey: 'songId',
        titleKey: 'songName',
      );

      final songs = await adapterWith(client, config: config).search('稻香');

      expect(songs.single.id, 'online-abc');
      expect(songs.single.title, '稻香');
    });

    test('baseUrl 带尾斜杠时归一化，不产生双斜杠路径', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'src.example');
        expect(request.url.path, '/api/search');
        return jsonResponse({'result': []});
      });
      const config = OnlineSourceConfig(baseUrl: 'https://src.example/api/');
      await adapterWith(client, config: config).search('x');
    });

    test('无 id 的结果被跳过', () async {
      final client = MockClient(
        (request) async => jsonResponse({
          'result': [
            {'name': '无id歌曲'},
            {'id': 1, 'name': '正常歌曲'},
          ],
        }),
      );

      final songs = await adapterWith(client).search('x');

      expect(songs.length, 1);
      expect(songs.single.title, '正常歌曲');
    });

    test('HTTP 非 200 → 用户可读异常', () async {
      final client = MockClient((request) async => http.Response('err', 404));
      await expectLater(
        adapterWith(client).search('x'),
        throwsA(
          isA<AppException>().having((e) => e.message, 'message', contains('404')),
        ),
      );
    });

    test('请求异常 → 映射为「无法连接到音乐源」', () async {
      final client = MockClient((request) async => throw Exception('boom'));
      await expectLater(
        adapterWith(client).search('x'),
        throwsA(
          isA<AppException>()
              .having((e) => e.message, 'message', '无法连接到音乐源'),
        ),
      );
    });

    test('响应缺结果列表 → 明确异常', () async {
      final client = MockClient(
        (request) async => jsonResponse({'foo': []}),
      );
      await expectLater(
        adapterWith(client).search('x'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('OnlineSourceAdapter.resolvePlayUrl', () {
    test('按配置参数与字段获取播放地址', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/song/url');
        expect(request.url.queryParameters['id'], '42');
        return jsonResponse({'url': 'https://cdn.example/42.mp3'});
      });
      final song = Song(
        id: 'online-42',
        title: '晴天',
        pathOrUrl: '',
        addedAt: DateTime(2026),
      );

      final url = await adapterWith(client).resolvePlayUrl(song);

      expect(url, 'https://cdn.example/42.mp3');
    });

    test('地址缺失 → 用户可读异常', () async {
      final client = MockClient(
        (request) async => jsonResponse({'url': ''}),
      );
      final song = Song(
        id: 'online-42',
        title: '晴天',
        pathOrUrl: '',
        addedAt: DateTime(2026),
      );

      await expectLater(
        adapterWith(client).resolvePlayUrl(song),
        throwsA(isA<AppException>()),
      );
    });
  });
}
