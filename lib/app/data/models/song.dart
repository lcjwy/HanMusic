import 'package:han_music/app/core/utils/hash.dart';

/// 歌曲来源。
enum SongSource { local, online, bili }

/// 统一歌曲模型：本地文件与网络流同构，播放器与歌单不感知来源差异。
///
/// [id] 是唯一标识与去重依据；相等性仅由 [id] 决定。
class Song {
  const Song({
    required this.id,
    required this.title,
    this.artist = defaultArtist,
    this.album = defaultAlbum,
    this.duration,
    this.coverUrl,
    this.source = SongSource.local,
    required this.pathOrUrl,
    required this.addedAt,
    this.missing = false,
  });

  static const defaultArtist = '未知歌手';
  static const defaultAlbum = '未知专辑';

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? coverUrl;
  final SongSource source;

  /// 本地文件路径或网络流地址。
  final String pathOrUrl;
  final DateTime addedAt;

  /// 本地源文件已不存在（仅展示灰显用，不参与相等性与持久化往返校验）。
  final bool missing;

  /// 由本地文件路径构造：id 基于路径稳定哈希；元数据缺省时以文件名兜底。
  factory Song.fromLocalFile({
    required String path,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverPath,
  }) {
    final name =
        Uri.file(path).pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? path;
    final dot = name.lastIndexOf('.');
    final fallbackTitle = dot > 0 ? name.substring(0, dot) : name;
    String orFallback(String? value, String defaultValue) =>
        (value == null || value.trim().isEmpty) ? defaultValue : value.trim();
    return Song(
      id: 'local-${stableHash(path)}',
      title: orFallback(title, fallbackTitle),
      artist: orFallback(artist, defaultArtist),
      album: orFallback(album, defaultAlbum),
      duration: duration,
      coverUrl: (coverPath == null || coverPath.isEmpty) ? null : coverPath,
      source: SongSource.local,
      pathOrUrl: path,
      addedAt: DateTime.now(),
    );
  }

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? coverUrl,
    String? pathOrUrl,
    bool? missing,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source,
      pathOrUrl: pathOrUrl ?? this.pathOrUrl,
      addedAt: addedAt,
      missing: missing ?? this.missing,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration?.inMilliseconds,
        'coverUrl': coverUrl,
        'source': source.name,
        'pathOrUrl': pathOrUrl,
        'addedAt': addedAt.toIso8601String(),
        'missing': missing,
      };

  /// 仅接受真实字符串，其他类型一律按缺失处理。
  /// （`value as String?` 遇到数字等类型会抛 TypeError 而非回退默认值）
  static String? _stringOf(Object? value) => value is String ? value : null;

  /// 字段缺失或类型异常时逐项回退默认值，保证损坏数据不阻断加载。
  factory Song.fromJson(Map<String, dynamic> json) {
    final id = _stringOf(json['id']);
    final pathOrUrl = _stringOf(json['pathOrUrl']);
    return Song(
      id: (id == null || id.isEmpty)
          ? 'song-${stableHash(pathOrUrl ?? '')}'
          : id,
      title: _stringOf(json['title']) ?? '未知标题',
      artist: _stringOf(json['artist']) ?? defaultArtist,
      album: _stringOf(json['album']) ?? defaultAlbum,
      duration: json['durationMs'] is num
          ? Duration(milliseconds: (json['durationMs'] as num).toInt())
          : null,
      coverUrl: _stringOf(json['coverUrl']),
      source: SongSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => SongSource.local,
      ),
      pathOrUrl: pathOrUrl ?? '',
      addedAt:
          DateTime.tryParse(_stringOf(json['addedAt']) ?? '') ?? DateTime.now(),
      missing: json['missing'] is bool ? json['missing'] as bool : false,
    );
  }

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Song($id, $title - $artist)';
}
