import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/data/sources/remote/ai_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonBody(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

AiClient clientWith(Future<http.Response> Function(http.Request) handler) =>
    AiClient(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-test',
      model: 'test-model',
      client: MockClient(handler),
    );

void main() {
  group('AiClient.chat', () {
    test('解析 choices[0].message.content', () async {
      final ai = clientWith((request) async {
        expect(request.url.toString(), 'https://api.example.com/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer sk-test');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'test-model');
        return jsonBody({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': ' [00:01.00]歌词 '},
            },
          ],
        });
      });
      expect(await ai.chat(system: 's', user: 'u'), '[00:01.00]歌词');
    });

    test('401/403 → Key 无效；402 → 余额不足；429 → 频率限制', () async {
      for (final entry in {
        401: 'AI Key 无效或无权限',
        403: 'AI Key 无效或无权限',
        402: 'AI 账户余额不足',
        429: '请求过于频繁',
      }.entries) {
        final ai = clientWith((_) async => jsonBody({}, entry.key));
        await expectLater(
          ai.chat(system: 's', user: 'u'),
          throwsA(
            isA<AppException>().having((e) => e.message, 'message', contains(entry.value)),
          ),
        );
      }
    });

    test('其他非 200 → 响应异常；空内容 → 明确提示', () async {
      final ai = clientWith((_) async => jsonBody({}, 500));
      await expectLater(
        ai.chat(system: 's', user: 'u'),
        throwsA(isA<AppException>().having(
          (e) => e.message, 'message', contains('HTTP 500'))),
      );

      final empty = clientWith((_) async => jsonBody({
            'choices': [
              {'message': {'content': '   '}},
            ],
          }));
      await expectLater(
        empty.chat(system: 's', user: 'u'),
        throwsA(isA<AppException>().having(
          (e) => e.message, 'message', 'AI 未返回内容，请重试')),
      );
    });

    test('连接异常 → 无法连接 AI 服务', () async {
      final ai = clientWith((_) async => throw Exception('boom'));
      await expectLater(
        ai.chat(system: 's', user: 'u'),
        throwsA(isA<AppException>().having(
          (e) => e.message, 'message', '无法连接 AI 服务')),
      );
    });
  });
}
