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
      LibrarySort.addedDesc => _stable(_addedDesc),
      LibrarySort.addedAsc => _stable(_addedAsc),
      LibrarySort.title => _stable(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        ),
      LibrarySort.artist => _stable(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        ),
    };
    songs.sort(comparator);
    return songs;
  }

  static int _addedDesc(Song a, Song b) => b.addedAt.compareTo(a.addedAt);

  static int _addedAsc(Song a, Song b) => a.addedAt.compareTo(b.addedAt);

  /// Dart 的 List.sort 不稳定：主键相同的条目（同批导入的 addedAt 常因
  /// 时钟粒度相同）每次排序可能重排，以 id 兜底保证展示顺序稳定。
  static Comparator<Song> _stable(Comparator<Song> primary) => (a, b) {
        final result = primary(a, b);
        return result != 0 ? result : a.id.compareTo(b.id);
      };

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
    final List<String> paths;
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: '选择音频文件',
        type: FileType.custom,
        allowedExtensions: AppConstants.audioExtensions,
      );
      paths = files.map((f) => f.path).whereType<String>().toList();
    } on Exception {
      // 部分平台/权限拒绝时选择器会抛异常，静默丢弃会让用户以为点了没反应
      Get.snackbar('无法打开文件选择器', '请检查权限后重试');
      return;
    }
    if (paths.isEmpty) return;
    await _runImport(() => _importer.importFiles(paths));
  }

  Future<void> importFolder() async {
    String? picked;
    try {
      picked = await FilePicker.getDirectoryPath(dialogTitle: '选择音乐文件夹');
    } on Exception {
      Get.snackbar('无法打开目录选择器', '请检查权限后重试');
      return;
    }
    // 提升为非空局部量：闭包捕获的变量不做空提升
    final dir = picked;
    if (dir == null) return;
    await _runImport(() => _importer.importDirectory(dir));
  }

  /// 执行导入并按结果提示：未执行时区分"已有任务进行中"与"无音频文件"。
  Future<void> _runImport(Future<bool> Function() task) async {
    final bool ran;
    try {
      ran = await task();
    } on Exception {
      // 目录不可读等扫描期异常：避免未处理异步错误且用户无感知
      Get.snackbar('导入失败', '扫描或读取文件时出错，请重试');
      return;
    }
    if (!ran) {
      if (_importer.importing.value) {
        Get.snackbar('导入进行中', '请等待当前导入完成后再试');
      } else {
        Get.snackbar('未找到音频文件', '所选位置没有可导入的音频文件');
      }
      return;
    }
    _notifyImportResult();
  }

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
