import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/app_settings.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/remote/online_source_adapter.dart';
import 'package:han_music/app/services/online_source_service.dart';
import 'package:han_music/app/services/settings_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _defaultConfig = OnlineSourceConfig(baseUrl: 'https://src.example/api');

OnlineSourceService serviceWith(
  http.Client client, {
  OnlineSourceConfig? config = _defaultConfig,
}) {
  final settings = SettingsService(MemoryStore());
  if (config != null) {
    settings.source.value = config;
  }
  Get.put<SettingsService>(settings);
  return OnlineSourceService(
    adapterFactory: (c) => OnlineSourceAdapter(c, client: client),
  );
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  test('未配置源时搜索抛出可读异常', () async {
    final service = serviceWith(
      MockClient((request) async => http.Response('{}', 200)),
      config: null,
    );
    await expectLater(
      service.search('x'),
      throwsA(
        isA<AppException>()
            .having((e) => e.message, 'message', '尚未配置网络音乐源'),
      ),
    );
  });

  test('旧请求晚到不覆盖新结果', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    var call = 0;
    final client = MockClient((request) async {
      call++;
      return call == 1 ? first.future : second.future;
    });
    final service = serviceWith(client);

    final searchOld = service.search('a');
    final searchNew = service.search('b');

    // 新请求先返回
    second.complete(
      http.Response(
        jsonEncode({
          'result': [
            {'id': 'b2', 'name': 'B'},
          ],
        }),
        200,
      ),
    );
    await searchNew;
    expect(service.results.single.id, 'online-b2');

    // 旧请求晚到：不覆盖
    first.complete(
      http.Response(
        jsonEncode({
          'result': [
            {'id': 'a1', 'name': 'A'},
          ],
        }),
        200,
      ),
    );
    await searchOld;
    expect(service.results.single.id, 'online-b2');
    expect(service.searching.value, isFalse);
  });

  test('搜索失败清空结果并抛出', () async {
    final service = serviceWith(
      MockClient((request) async => http.Response('error', 500)),
    );
    await expectLater(service.search('x'), throwsA(isA<AppException>()));
    expect(service.results, isEmpty);
    expect(service.searching.value, isFalse);
  });

  test('searchDebounced：500ms 防抖，多次输入只发一次请求', () {
    fakeAsync((async) {
      var adapterCreated = 0;
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'result': []}), 200),
      );
      final settings = SettingsService(MemoryStore());
      settings.source.value = _defaultConfig;
      Get.put<SettingsService>(settings);
      final service = OnlineSourceService(
        adapterFactory: (config) {
          adapterCreated++;
          return OnlineSourceAdapter(config, client: client);
        },
      );

      service.searchDebounced('abc');
      async.elapse(const Duration(milliseconds: 200));
      service.searchDebounced('abcd');
      async.elapse(const Duration(milliseconds: 300));
      expect(adapterCreated, 0, reason: '首次输入的计时器应被取消');

      async.elapse(const Duration(milliseconds: 300));
      expect(adapterCreated, 1, reason: '距最后一次输入 500ms 后应发起一次搜索');
    });
  });

  test('空关键字防抖：清空结果且不发起请求', () {
    fakeAsync((async) {
      var adapterCreated = 0;
      final settings = SettingsService(MemoryStore());
      settings.source.value = _defaultConfig;
      Get.put<SettingsService>(settings);
      final service = OnlineSourceService(
        adapterFactory: (config) {
          adapterCreated++;
          return OnlineSourceAdapter(
            config,
            client: MockClient((request) async => http.Response('{}', 200)),
          );
        },
      );
      service.results.add(
        Song(id: 'online-1', title: 'x', pathOrUrl: '', addedAt: DateTime(2026)),
      );

      service.searchDebounced('');

      expect(service.results, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(adapterCreated, 0);
    });
  });
}
