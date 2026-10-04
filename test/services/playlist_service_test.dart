import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/playlist.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/playlist_service.dart';

void main() {
  late MemoryStore store;
  late PlaylistService service;

  setUp(() {
    store = MemoryStore();
    service = PlaylistService(store);
  });

  Song song(String path) => Song.fromLocalFile(path: path);

  test('首次加载补建内置收藏歌单：不可删除、不可重命名', () async {
    await service.load();
    final fav = service.byId(Playlist.favoriteId);
    expect(fav, isNotNull);
    expect(fav!.deletable, isFalse);
    expect(fav.name, '我喜欢的音乐');
    expect(service.playlists.first.id, Playlist.favoriteId);

    expect(await service.delete(Playlist.favoriteId), isFalse);
    expect(await service.rename(Playlist.favoriteId, '新名字'), isFalse);
    expect(service.byId(Playlist.favoriteId)!.name, '我喜欢的音乐');
  });

  test('新建/重命名/删除 CRUD，变更持久化可恢复', () async {
    await service.load();
    final created = await service.create(name: '通勤', coverId: 'ocean');
    expect(service.playlists.length, 2);

    expect(await service.rename(created.id, '通勤歌单'), isTrue);
    expect(service.byId(created.id)!.name, '通勤歌单');

    await service.addSongs(created.id, [song('/a.mp3')]);
    expect(await service.delete(created.id), isTrue);
    expect(service.byId(created.id), isNull);

    // 删除不影响歌曲收藏歌单与持久化内容；重载后仍只有收藏歌单
    final reloaded = PlaylistService(store);
    await reloaded.load();
    expect(reloaded.playlists.length, 1);
    expect(reloaded.playlists.first.id, Playlist.favoriteId);
  });

  test('加入歌曲去重：返回新增/跳过数量，重复添加不产生重复项', () async {
    await service.load();
    final created = await service.create(name: '夜跑');
    final first = await service.addSongs(
      created.id,
      [song('/a.mp3'), song('/a.mp3'), song('/b.mp3')],
    );
    expect(first.added, 2);
    expect(first.skipped, 1);
    expect(service.byId(created.id)!.songs.length, 2);

    final again = await service.addSongs(created.id, [song('/b.mp3')]);
    expect(again.added, 0);
    expect(again.skipped, 1);
    expect(service.byId(created.id)!.songs.length, 2);
  });

  test('收藏 toggle：双向切换，favoriteIds 同步，可恢复', () async {
    await service.load();
    final a = song('/a.mp3');
    expect(await service.toggleFavorite(a), isTrue);
    expect(service.isFavorite(a.id), isTrue);
    expect(service.byId(Playlist.favoriteId)!.songs.length, 1);

    expect(await service.toggleFavorite(a), isFalse);
    expect(service.isFavorite(a.id), isFalse);
    expect(service.byId(Playlist.favoriteId)!.songs.length, 0);

    await service.toggleFavorite(a);
    final reloaded = PlaylistService(store);
    await reloaded.load();
    expect(reloaded.isFavorite(a.id), isTrue);
  });

  test('单曲移除与拖拽排序', () async {
    await service.load();
    final created = await service.create(name: '排序');
    await service.addSongs(
      created.id,
      [song('/a.mp3'), song('/b.mp3'), song('/c.mp3')],
    );

    expect(await service.removeSong(created.id, song('/b.mp3').id), isTrue);
    expect(
      service.byId(created.id)!.songs.map((s) => s.title),
      ['a', 'c'],
    );

    // a c → 把 c（索引1）移到最前
    await service.moveSong(created.id, 1, 0);
    expect(
      service.byId(created.id)!.songs.map((s) => s.title),
      ['c', 'a'],
    );
    // 越界与原地移动安全
    await service.moveSong(created.id, 5, 0);
    await service.moveSong(created.id, 0, 1);
    expect(
      service.byId(created.id)!.songs.map((s) => s.title),
      ['c', 'a'],
    );
  });

  test('封面更新：切回内置封面时清理旧自定义文件，持久化往返', () async {
    final deleted = <String>[];
    final tracked = PlaylistService(store, fileDelete: deleted.add);
    await tracked.load();
    final created = await tracked.create(name: '封面');

    await tracked.updateCover(created.id, coverId: 'ocean', coverPath: null);
    await tracked.updateCover(
      created.id,
      coverId: 'ocean',
      coverPath: '/covers/custom.png',
    );
    expect(tracked.byId(created.id)!.coverPath, '/covers/custom.png');

    // 换回内置封面：旧自定义文件被清理
    await tracked.updateCover(created.id, coverId: 'mint', coverPath: null);
    expect(tracked.byId(created.id)!.coverPath, isNull);
    expect(deleted, ['/covers/custom.png']);

    final reloaded = PlaylistService(store);
    await reloaded.load();
    expect(reloaded.byId(created.id)!.coverId, 'mint');
  });

  test('clearAll 清空自建歌单与收藏内容，收藏歌单本身保留', () async {
    await service.load();
    await service.create(name: '甲');
    await service.create(name: '乙');
    await service.toggleFavorite(song('/a.mp3'));

    await service.clearAll();

    expect(service.playlists.length, 1);
    expect(service.playlists.first.id, Playlist.favoriteId);
    expect(service.playlists.first.songs, isEmpty);
    expect(service.isFavorite(song('/a.mp3').id), isFalse);

    final reloaded = PlaylistService(store);
    await reloaded.load();
    expect(reloaded.playlists.length, 1);
    expect(reloaded.playlists.first.songs, isEmpty);
  });

  test('数据损坏时按空处理并补建收藏歌单', () async {
    await store.write('playlists', '{broken json');
    await service.load();
    expect(service.playlists.length, 1);
    expect(service.playlists.first.id, Playlist.favoriteId);
  });
}
