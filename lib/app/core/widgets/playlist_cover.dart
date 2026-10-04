import 'package:flutter/material.dart';

import 'package:han_music/app/core/utils/hash.dart';
import 'package:han_music/app/core/widgets/cover_provider.dart';

/// 内置歌单封面定义：渐变配色，随代码内置，无需打包图片资源。
class BuiltInPlaylistCover {
  const BuiltInPlaylistCover(this.id, this.label, this.colors);

  final String id;
  final String label;
  final List<Color> colors;
}

/// 内置封面集合：歌单封面由此选择；用户也可上传自定义图片覆盖。
abstract final class BuiltInPlaylistCovers {
  static const all = <BuiltInPlaylistCover>[
    BuiltInPlaylistCover('sunrise', '日出', [Color(0xFFFF9A56), Color(0xFFFF5E62)]),
    BuiltInPlaylistCover('ocean', '海雾', [Color(0xFF4FC3F7), Color(0xFF1565C0)]),
    BuiltInPlaylistCover('forest', '森林', [Color(0xFF81C784), Color(0xFF2E7D32)]),
    BuiltInPlaylistCover('violet', '星夜', [Color(0xFF7986CB), Color(0xFF303F9F)]),
    BuiltInPlaylistCover('rose', '蔷薇', [Color(0xFFF48FB1), Color(0xFFAD1457)]),
    BuiltInPlaylistCover('amber', '琥珀', [Color(0xFFFFD54F), Color(0xFFFF8F00)]),
    BuiltInPlaylistCover('mint', '薄荷', [Color(0xFF80CBC4), Color(0xFF00695C)]),
    BuiltInPlaylistCover('dusk', '暮色', [Color(0xFF9575CD), Color(0xFF512DA8)]),
    BuiltInPlaylistCover('slate', '石墨', [Color(0xFF90A4AE), Color(0xFF37474F)]),
    BuiltInPlaylistCover('coral', '珊瑚', [Color(0xFFFF8A65), Color(0xFFD84315)]),
  ];

  static BuiltInPlaylistCover? byId(String id) {
    for (final cover in all) {
      if (cover.id == id) return cover;
    }
    return null;
  }

  /// 无效/缺失 id 时的确定性兜底：同一歌单稳定取同一张。
  static BuiltInPlaylistCover fallbackFor(String seed) {
    final value = int.tryParse(stableHash(seed).substring(0, 6), radix: 16) ?? 0;
    return all[value % all.length];
  }
}

/// 歌单封面：自定义图片 > 内置渐变 > 按 id 稳定兜底渐变。
class PlaylistCoverArt extends StatelessWidget {
  const PlaylistCoverArt({
    super.key,
    this.coverId,
    this.coverPath,
    this.size = 48,
    this.radius = 8,
    double? iconSize,
    this.expand = false,
  })  : iconSize = iconSize ?? 24;

  final String? coverId;
  final String? coverPath;

  /// 固定边长（[expand] 为 false 时生效）。
  final double size;
  final double radius;
  final double iconSize;

  /// 填满父级约束（歌单网格/详情大图），与 [AspectRatio]/Expanded 搭配使用。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget? image;
    final path = coverPath;
    if (path != null && path.isNotEmpty) {
      // localCoverProvider 对缺失文件返回 null，自动落回渐变兜底
      final provider = localCoverProvider(path);
      if (provider != null) {
        image = Image(
          image: provider,
          fit: BoxFit.cover,
          width: expand ? null : size,
          height: expand ? null : size,
          errorBuilder: (_, _, _) => _gradientBox(),
        );
      }
    }
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: expand
          ? SizedBox.expand(child: image ?? _gradientBox())
          : SizedBox(
              width: size,
              height: size,
              child: image ?? _gradientBox(),
            ),
    );
    return content;
  }

  Widget _gradientBox() {
    final seed = coverPath ?? coverId ?? '';
    final cover =
        BuiltInPlaylistCovers.byId(coverId ?? '') ??
        BuiltInPlaylistCovers.fallbackFor(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cover.colors,
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note, size: iconSize, color: Colors.white70),
      ),
    );
  }
}
