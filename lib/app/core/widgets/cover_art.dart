import 'package:flutter/material.dart';
import 'package:han_music/app/core/widgets/cover_provider.dart';

/// 封面组件：本地路径或网络地址统一渲染，缺失时显示音符占位。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    this.url,
    this.size = 48,
    this.radius = 8,
    double? iconSize,
  })  : iconSize = iconSize ?? 24;

  /// 本地文件路径或 http(s) 地址，可为空。
  final String? url;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = this.url;

    ImageProvider? provider;
    if (url != null && url.isNotEmpty) {
      provider = url.startsWith('http')
          ? NetworkImage(url)
          : localCoverProvider(url);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: provider == null
            ? Icon(Icons.music_note, size: iconSize, color: colorScheme.outline)
            : Image(
                image: provider,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note,
                  size: iconSize,
                  color: colorScheme.outline,
                ),
              ),
      ),
    );
  }
}
