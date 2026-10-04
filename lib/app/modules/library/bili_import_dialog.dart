import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/core/widgets/cover_art.dart';
import 'package:han_music/app/data/models/bili_cache.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/data/sources/bili/bili_cache_scanner.dart';
import 'package:han_music/app/services/library_service.dart';

/// B站缓存导入（F9）：SAF/目录选择器授权缓存根目录 → 扫描分P →
/// 勾选可导入项（audio.m4s 零转换直接入库）→ 批量加入曲库。
Future<void> showBiliImportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _BiliImportDialog(),
  );
}

class _BiliImportDialog extends StatefulWidget {
  const _BiliImportDialog();

  @override
  State<_BiliImportDialog> createState() => _BiliImportDialogState();
}

class _BiliImportDialogState extends State<_BiliImportDialog> {
  String? _rootPath;
  bool _scanning = false;
  List<BiliCacheEntry> _entries = const [];
  final _selected = <int>{};

  LibraryService get _library => Get.find<LibraryService>();

  Future<void> _pickAndScan() async {
    String? picked;
    try {
      picked = await FilePicker.getDirectoryPath(dialogTitle: '选择 B站缓存 download 目录');
    } on Exception {
      Get.snackbar('无法打开目录选择器', '请检查权限后重试');
      return;
    }
    if (picked == null) return;
    setState(() {
      _rootPath = picked;
      _scanning = true;
      _entries = const [];
      _selected.clear();
    });
    try {
      final entries = await scanBiliCache(picked);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        for (var i = 0; i < entries.length; i++) {
          if (entries[i].importable) _selected.add(i);
        }
        _scanning = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _scanning = false);
      Get.snackbar('扫描失败', '目录不可读，请重新选择或检查授权');
    }
  }

  Future<void> _import() async {
    final songs = _selected
        .map((i) => _entries[i].toSong())
        .whereType<Song>()
        .toList();
    if (songs.isEmpty) return;
    final added = await _library.addAll(songs);
    if (!mounted) return;
    Navigator.of(context).pop();
    final skippedInBatch = songs.length - added;
    Get.snackbar(
      '导入完成',
      '新增 $added 首${skippedInBatch > 0 ? '，$skippedInBatch 首已在曲库中' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('导入 B站缓存音频'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: _rootPath == null ? _buildIntro(theme) : _buildResult(theme),
      ),
      actions: [
        if (_rootPath != null)
          TextButton(
            onPressed: _scanning ? null : _pickAndScan,
            child: const Text('重选目录'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (_entries.isNotEmpty)
          FilledButton(
            onPressed: _scanning || _selected.isEmpty ? null : _import,
            child: Text('导入所选（${_selected.length}）'),
          ),
      ],
    );
  }

  Widget _buildIntro(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '将扫描 B站客户端离线缓存，仅提取音频轨（audio.m4s）加入曲库，'
          '视频轨不做任何处理；默认零转换直接播放。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Android 11+ 需通过系统目录选择器授权 B站的 download 目录；'
          '若系统受限，可先用文件管理器把缓存拷贝到可访问位置。',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: _pickAndScan,
          icon: const Icon(Icons.folder_open),
          label: const Text('选择缓存目录并扫描'),
        ),
      ],
    );
  }

  Widget _buildResult(ThemeData theme) {
    if (_scanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在扫描缓存目录…'),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          '未发现可识别的缓存分P（entry.json）\n请确认选择的是 B站 download 目录',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }
    final okCount = _selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '发现 ${_entries.length} 个分P，已选 $okCount 个',
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                for (var i = 0; i < _entries.length; i++) {
                  if (_entries[i].importable) _selected.add(i);
                }
              }),
              child: const Text('全选'),
            ),
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('反选'),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final checked = _selected.contains(index);
              if (!entry.importable) {
                return ListTile(
                  enabled: false,
                  dense: true,
                  leading: const Icon(Icons.error_outline),
                  title: Text(entry.title, maxLines: 1),
                  subtitle: Text(entry.problem ?? '无法导入'),
                );
              }
              return CheckboxListTile(
                dense: true,
                value: checked,
                secondary: CoverArt(url: null, size: 40, iconSize: 18),
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${entry.artist} · ${entry.album}'
                  '${entry.duration == null ? '' : ' · ${formatDuration(entry.duration)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (value) => setState(() {
                  value == true ? _selected.add(index) : _selected.remove(index);
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
