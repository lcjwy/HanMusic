import 'package:get/get.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/library_service.dart';
import 'package:han_music/app/services/player_service.dart';

/// 曲库排序方式。
enum LibrarySort { addedDesc, addedAsc, title, artist }

extension LibrarySortX on LibrarySort {
  String get label => switch (this) {
        LibrarySort.addedDesc => '最近添加',
        LibrarySort.addedAsc => '最早添加',
        LibrarySort.title => '按标题',
        LibrarySort.artist => '按歌手',
      };
}

/// 本地音乐库 ViewModel：过滤、排序、播放入口；导入逻辑见导入服务。
class LibraryController extends GetxController {
  LibraryService get _library => Get.find<LibraryService>();
  PlayerService get _player => Get.find<PlayerService>();

  final query = ''.obs;
  final sortBy = LibrarySort.addedDesc.obs;

  /// 关键字过滤（标题/歌手/专辑）+ 排序后的展示列表。
  List<Song> visibleSongs() {
    var songs = _library.songs.toList();
    final q = query.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      songs = songs
          .where(
            (s) =>
                s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q) ||
                s.album.toLowerCase().contains(q),
          )
          .toList();
    }
    final Comparator<Song> comparator = switch (sortBy.value) {
      LibrarySort.addedDesc => (a, b) => b.addedAt.compareTo(a.addedAt),
      LibrarySort.addedAsc => (a, b) => a.addedAt.compareTo(b.addedAt),
      LibrarySort.title => (a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      LibrarySort.artist => (a, b) =>
          a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
    };
    songs.sort(comparator);
    return songs;
  }

  /// 以当前可见列表（排除缺失文件）为队列，从点击项开始播放。
  Future<void> playVisible(int index) async {
    final songs = visibleSongs().where((s) => !s.missing).toList();
    if (songs.isEmpty) return;
    final tapped = visibleSongs()[index.clamp(0, visibleSongs().length - 1)];
    final target = songs.indexOf(tapped);
    if (target < 0) {
      // 点中的是缺失文件：排除后不在可播队列里
      Get.snackbar('无法播放', '该文件已不存在，请重新导入');
      return;
    }
    await _player.playQueue(songs, initialIndex: target);
  }
}
