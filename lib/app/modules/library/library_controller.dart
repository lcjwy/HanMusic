import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/library_import_service.dart';
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

/// 本地音乐库 ViewModel：过滤、排序、播放入口、导入、多选删除。
class LibraryController extends GetxController {
  LibraryService get _library => Get.find<LibraryService>();
  LibraryImportService get _importer => Get.find<LibraryImportService>();
  PlayerService get _player => Get.find<PlayerService>();

  final query = ''.obs;
  final sortBy = LibrarySort.addedDesc.obs;

  /// 多选模式下的选中集合（空即非选择模式）。
  final selected = <Song>{}.obs;

  bool get selecting => selected.isNotEmpty;

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
    final visible = visibleSongs();
    final tapped = visible[index.clamp(0, visible.length - 1)];
    if (tapped.missing) {
      Get.snackbar('无法播放', '该文件已不存在，请重新导入');
      return;
    }
    final playable = visible.where((s) => !s.missing).toList();
    await _player.playQueue(playable, initialIndex: playable.indexOf(tapped));
  }

  void toggleSelected(Song song) {
    if (selected.contains(song)) {
      selected.remove(song);
    } else {
      selected.add(song);
    }
  }

  void clearSelection() => selected.clear();

  Future<void> importFiles() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: '选择音频文件',
      type: FileType.custom,
      allowedExtensions: AppConstants.audioExtensions,
    );
    final paths = files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    await _importer.importFiles(paths);
    _notifyImportResult();
  }

  Future<void> importFolder() async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择音乐文件夹');
    if (dir == null) return;
    await _importer.importDirectory(dir);
    _notifyImportResult();
  }

  void cancelImport() => _importer.cancel();

  /// 移除选中项（仅删索引，不动源文件），退出选择模式。
  Future<void> removeSelected() async {
    final targets = selected.toSet();
    await _library.removeSongs(targets);
    selected.clear();
    Get.snackbar('已移除', '${targets.length} 首歌曲已从曲库移除');
  }

  void _notifyImportResult() {
    final importer = _importer;
    if (importer.cancelled) {
      Get.snackbar('已取消', '本次导入了 ${importer.added.value} 首歌曲');
    } else {
      Get.snackbar('导入完成', '新增 ${importer.added.value} 首，共扫描 ${importer.total.value} 个文件');
    }
  }
}
