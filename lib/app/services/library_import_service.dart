import 'package:get/get.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/local/local_importer.dart';
import 'package:han_music/app/services/library_service.dart';

/// 本地曲库导入服务：选择来源（文件/目录）→ 逐个读元数据 → 去重入库。
///
/// 支持进度展示与取消；导入一次性批量持久化。
class LibraryImportService extends GetxService {
  LibraryImportService(this._library);

  final LibraryService _library;

  final importing = false.obs;
  final scanned = 0.obs;
  final total = 0.obs;
  final added = 0.obs;
  final currentName = ''.obs;

  bool _cancelRequested = false;
  bool _lastRunCancelled = false;

  /// 上一次导入是否被用户取消。
  bool get cancelled => _lastRunCancelled;

  /// 导入用户选择的音频文件（本地绝对路径）。
  Future<void> importFiles(List<String> paths) => _run(paths);

  /// 递归导入目录下的音频文件。
  Future<void> importDirectory(String dirPath) async {
    await _run(scanAudioFiles(dirPath));
  }

  /// 请求取消当前导入任务（处理完当前文件后停止）。
  void cancel() => _cancelRequested = true;

  Future<void> _run(List<String> paths) async {
    if (importing.value || paths.isEmpty) return;
    importing.value = true;
    _cancelRequested = false;
    _lastRunCancelled = false;
    total.value = paths.length;
    scanned.value = 0;
    added.value = 0;

    final batch = <Song>[];
    try {
      for (final path in paths) {
        if (_cancelRequested) {
          _lastRunCancelled = true;
          break;
        }
        currentName.value =
            Uri.file(path).pathSegments.where((s) => s.isNotEmpty).lastOrNull ??
                path;
        if (!_library.containsPath(path)) {
          batch.add(await songFromFile(path));
          added.value += 1;
        }
        scanned.value += 1;
      }
    } finally {
      if (batch.isNotEmpty) {
        _library.addAll(batch);
      }
      importing.value = false;
      currentName.value = '';
    }
  }
}
