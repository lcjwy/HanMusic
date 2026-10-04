import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/history_service.dart';

void main() {
  late MemoryStore store;
  late HistoryService service;
  var clockTick = 0;

  DateTime fakeNow() => DateTime(2026, 1, 1).add(Duration(minutes: clockTick++));

  setUp(() {
    store = MemoryStore();
    clockTick = 0;
    service = HistoryService(store, now: fakeNow);
  });

  Song song(String path) => Song.fromLocalFile(path: path, title: path);

  test('记录去重置顶：同曲仅保留最近一条，时间倒序', () async {
    await service.record(song('/a.mp3'));
    await service.record(song('/b.mp3'));
    await service.record(song('/a.mp3'));

    expect(service.entries.length, 2);
    expect(service.entries.first.song.title, '/a.mp3');
    expect(service.entries.last.song.title, '/b.mp3');
  });

  test('超限淘汰最旧（上限 200）', () async {
    for (var i = 0; i < 205; i++) {
      await service.record(song('/s$i.mp3'));
    }
    expect(service.entries.length, 200);
    expect(service.entries.first.song.title, '/s204.mp3');
    expect(service.entries.last.song.title, '/s5.mp3');
  });

  test('清空与持久化往返', () async {
    await service.record(song('/a.mp3'));
    final reloaded = HistoryService(store);
    await reloaded.load();
    expect(reloaded.entries.length, 1);
    expect(reloaded.entries.first.song.id, song('/a.mp3').id);

    await reloaded.clear();
    final again = HistoryService(store);
    await again.load();
    expect(again.entries, isEmpty);
  });

  test('损坏数据按空历史处理', () async {
    await store.write('history', '{broken');
    await service.load();
    expect(service.entries, isEmpty);
  });
}
