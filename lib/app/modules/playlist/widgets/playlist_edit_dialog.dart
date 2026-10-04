import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/io/cover_store.dart';
import 'package:han_music/app/core/widgets/playlist_cover.dart';
import 'package:han_music/app/data/models/playlist.dart';
import 'package:han_music/app/services/playlist_service.dart';

/// 新建/编辑歌单对话框：命名 + 封面选择（内置图网格或自定义图片）。
/// 返回创建/更新后的歌单；取消返回 null。
Future<Playlist?> showPlaylistEditDialog(
  BuildContext context, {
  Playlist? existing,
}) {
  return showDialog<Playlist>(
    context: context,
    builder: (_) => _PlaylistEditDialog(existing: existing),
  );
}

class _PlaylistEditDialog extends StatefulWidget {
  const _PlaylistEditDialog({this.existing});

  final Playlist? existing;

  @override
  State<_PlaylistEditDialog> createState() => _PlaylistEditDialogState();
}

class _PlaylistEditDialogState extends State<_PlaylistEditDialog> {
  late final TextEditingController _name;
  late String? _coverId;
  late String? _customCoverPath;
  bool _picking = false;

  bool get _renamable => widget.existing?.deletable ?? true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _coverId = widget.existing?.coverId;
    _customCoverPath = widget.existing?.coverPath;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickCustomCover() async {
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: '选择封面图片',
        type: FileType.image,
      );
      final path = files.map((f) => f.path).whereType<String>().firstOrNull;
      if (path == null) return;
      final ext = path.split('.').last.toLowerCase();
      final owner = widget.existing?.id ?? 'new';
      final fileName =
          'playlist-$owner-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final copied = await copyIntoAppCovers(path, fileName);
      if (copied == null) {
        Get.snackbar('无法使用自定义封面', '当前平台不支持或图片复制失败');
        return;
      }
      if (mounted) setState(() => _customCoverPath = copied);
    } on Exception {
      Get.snackbar('无法打开图片选择器', '请检查权限后重试');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      Get.snackbar('无法保存', '请输入歌单名称');
      return;
    }
    final service = Get.find<PlaylistService>();
    final existing = widget.existing;
    final Playlist result;
    if (existing == null) {
      result = await service.create(
        name: name,
        coverId: _coverId,
        coverPath: _customCoverPath,
      );
    } else {
      await service.updateCover(
        existing.id,
        coverId: _coverId,
        coverPath: _customCoverPath,
      );
      if (_renamable && name != existing.name) {
        await service.rename(existing.id, name);
      }
      result = service.byId(existing.id) ?? existing;
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? '新建歌单' : '编辑歌单'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                enabled: _renamable,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: _renamable ? '歌单名称' : '歌单名称（内置歌单不可重命名）',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 96,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: BuiltInPlaylistCovers.all.length + 1,
                  itemBuilder: (context, index) {
                    if (index == BuiltInPlaylistCovers.all.length) {
                      return _CustomCoverCell(
                        path: _customCoverPath,
                        fallbackCoverId: _coverId,
                        selected: _customCoverPath != null,
                        picking: _picking,
                        onTap: _picking ? null : _pickCustomCover,
                      );
                    }
                    final cover = BuiltInPlaylistCovers.all[index];
                    final selected =
                        _customCoverPath == null && _coverId == cover.id;
                    return _CoverCell(
                      selected: selected,
                      onTap: () => setState(() {
                        _coverId = cover.id;
                        _customCoverPath = null;
                      }),
                      child: PlaylistCoverArt(
                        coverId: cover.id,
                        expand: true,
                        iconSize: 26,
                      ),
                    );
                  },
                ),
              ),
              if (_picking) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              Text(
                '封面可选内置图或上传自定义图片；图片会复制到应用数据目录。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _picking ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CoverCell extends StatelessWidget {
  const _CoverCell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(7), child: child),
      ),
    );
  }
}

class _CustomCoverCell extends StatelessWidget {
  const _CustomCoverCell({
    required this.path,
    required this.fallbackCoverId,
    required this.selected,
    required this.picking,
    required this.onTap,
  });

  final String? path;
  final String? fallbackCoverId;
  final bool selected;
  final bool picking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return _CoverCell(
      selected: selected,
      onTap: onTap,
      child: path == null
          ? Container(
              color: colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 22, color: colorScheme.outline),
                  const SizedBox(height: 4),
                  Text('自定义', style: theme.textTheme.labelSmall),
                ],
              ),
            )
          : PlaylistCoverArt(
              coverPath: path,
              coverId: fallbackCoverId,
              expand: true,
              iconSize: 26,
            ),
    );
  }
}
