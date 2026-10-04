import 'package:han_music/app/core/utils/hash.dart';
import 'package:han_music/app/data/models/song.dart';

/// B站离线缓存的可导入条目（每个分P目录一项）。
///
/// [problem] 非 null 表示无法导入及原因（entry.json 解析失败 /
/// 缺 audio.m4s），不阻断其余条目。
class BiliCacheEntry {
  const BiliCacheEntry({
    required this.pageDir,
    required this.audioPath,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.problem,
  });

  /// 分P目录（entry.json 所在目录）。
  final String pageDir;

  /// audio.m4s 绝对路径（fMP4 音轨，可直接播放，零转换）。
  final String audioPath;

  /// 标题 = 分P名，缺省回退视频标题 / 目录名。
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? problem;

  bool get importable => problem == null && audioPath.isNotEmpty;

  /// 转为统一歌曲模型：id 基于音轨路径稳定哈希，重复导入按路径去重。
  Song? toSong() {
    if (!importable) return null;
    return Song(
      id: 'bili-${stableHash(audioPath)}',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      source: SongSource.bili,
      pathOrUrl: audioPath,
      addedAt: DateTime.now(),
    );
  }
}
