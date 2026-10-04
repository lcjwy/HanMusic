import 'package:han_music/app/core/utils/hash.dart';
import 'package:han_music/app/data/models/song.dart';

/// 歌单：自建歌单与内置收藏歌单的统一模型。
///
/// 歌曲以快照形式存储（与播放队列一致的 JSON 往返），本地/在线歌曲均可入列；
/// 同一歌单内按 [Song.id] 去重。
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.coverId,
    this.coverPath,
    required this.songs,
    required this.createdAt,
    this.deletable = true,
  });

  /// 内置收藏歌单的固定 id：不可删除、不可重命名。
  static const favoriteId = 'fav';

  final String id;
  final String name;

  /// 内置封面 id（见 BuiltInPlaylistCovers）；[coverPath] 存在时优先使用。
  final String? coverId;

  /// 自定义封面图片的本地路径（导入时复制进应用专属目录）。
  final String? coverPath;
  final List<Song> songs;
  final DateTime createdAt;

  /// 是否允许删除/重命名（内置收藏歌单为 false；封面仍可自定义）。
  final bool deletable;

  Playlist copyWith({
    String? name,
    String? coverId,
    String? coverPath,
    List<Song>? songs,
    bool clearCoverPath = false,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      coverId: coverId ?? this.coverId,
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      songs: songs ?? this.songs,
      createdAt: createdAt,
      deletable: deletable,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coverId': coverId,
        'coverPath': coverPath,
        'songs': songs.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'deletable': deletable,
      };

  /// 字段缺失或类型异常时逐项回退默认值，保证损坏数据不阻断加载。
  factory Playlist.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return Playlist(
      id: id is String && id.isNotEmpty
          ? id
          : 'playlist-${stableHash('${json['name']}${json['createdAt']}')}',
      name: json['name'] is String && (json['name'] as String).trim().isNotEmpty
          ? json['name'] as String
          : '未命名歌单',
      coverId: json['coverId'] is String ? json['coverId'] as String : null,
      coverPath:
          json['coverPath'] is String ? json['coverPath'] as String : null,
      songs: json['songs'] is List
          ? (json['songs'] as List)
              .whereType<Map>()
              .map(
                (m) => Song.fromJson(m.cast<String, dynamic>()),
              )
              .toList()
          : <Song>[],
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      deletable: json['deletable'] is bool ? json['deletable'] as bool : true,
    );
  }
}
