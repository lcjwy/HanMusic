import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/library_service.dart';

Song localSong(String path) => Song.fromLocalFile(path: path);

void main() {
  late MemoryStore store;
  late LibraryService service;

  setUp(() {
    store = MemoryStore();
    service = LibraryService(store, fileExists: (_) => true);
  });

  test('批量导入按路径去重，返回新增数量', () async {
    final first = await service.addAll([localSong('/m/a.mp3'), localSong('/m/b.mp3')]);
    expect(first, 2);
    expect(service.songs.length, 2);

    final second = await service.addAll(
      [localSong('/m/a.mp3'), localSong('/m/c.mp3')],
    );
    expect(second, 1);
    expect(service.songs.length, 3);
  });

  test('导入输入含重复路径时去重', () async {
    final added = await service.addAll(
      [localSong('/m/a.mp3'), localSong('/m/a.mp3')],
    );
    expect(added, 1);
    expect(service.songs.length, 1);
  });

  test('removeSongs 仅移除索引，持久化生效', () async {
    await service.addAll([localSong('/m/a.mp3'), localSong('/m/b.mp3')]);
    await service.removeSongs([localSong('/m/a.mp3')]);
    expect(service.songs.length, 1);
    expect(service.songs.single.pathOrUrl, '/m/b.mp3');
  });

  test('重启加载后对缺失文件标记 missing', () async {
    await service.addAll([localSong('/m/exists.mp3'), localSong('/m/gone.mp3')]);

    final restored = LibraryService(
      store,
      fileExists: (path) => path.endsWith('exists.mp3'),
    );
    await restored.load();

    final exists = restored.songs.firstWhere((s) => s.title == 'exists');
    final gone = restored.songs.firstWhere((s) => s.title == 'gone');
    expect(exists.missing, isFalse);
    expect(gone.missing, isTrue);
  });

  test('clear 清空索引并持久化', () async {
    await service.addAll([localSong('/m/a.mp3')]);
    await service.clear();
    expect(service.songs, isEmpty);

    final restored = LibraryService(store, fileExists: (_) => true);
    await restored.load();
    expect(restored.songs, isEmpty);
  });

  test('索引内容损坏时按空曲库处理', () async {
    await store.write('library_index', '[broken');
    final restored = LibraryService(store, fileExists: (_) => true);
    await restored.load();
    expect(restored.songs, isEmpty);
  });
}
