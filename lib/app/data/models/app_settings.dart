/// 应用主题模式：独立于 Flutter 的 ThemeMode，服务层不依赖 UI 库。
enum AppThemeMode { system, light, dark }

/// 网络音乐源配置：通用适配器所需的全部描述（接口路径 + 请求参数名 + 响应字段映射）。
///
/// 不内置任何具体平台；用户在设置页按自己源的实际返回结构调整映射即可。
class OnlineSourceConfig {
  const OnlineSourceConfig({
    required this.baseUrl,
    this.searchPath = '/search',
    this.playPath = '/song/url',
    this.lyricsPath = '',
    this.searchKeywordKey = 'keywords',
    this.searchListKey = 'result',
    this.idKey = 'id',
    this.titleKey = 'name',
    this.artistKey = 'artist',
    this.albumKey = 'album',
    this.durationKey = 'duration',
    this.coverKey = 'cover',
    this.playIdParam = 'id',
    this.playUrlKey = 'url',
    this.lyricsIdParam = 'id',
    this.lyricsKey = 'lyric',
  });

  /// 源根地址，如 `https://example.com/api`（不含末尾斜杠）。
  final String baseUrl;

  /// 搜索接口路径，关键词以 [searchKeywordKey] 为参数名拼接。
  final String searchPath;

  /// 取播放地址接口路径，歌曲 id 以 [playIdParam] 为参数名拼接。
  final String playPath;

  /// 歌词接口路径（LRC 或纯文本）；为空表示源不提供歌词。
  final String lyricsPath;

  // ---- 请求参数名 ----
  final String searchKeywordKey;
  final String playIdParam;

  // ---- 响应字段映射（支持 `a.b` 点路径取嵌套字段）----
  /// 搜索响应中结果列表所在字段。
  final String searchListKey;
  final String idKey;
  final String titleKey;
  final String artistKey;
  final String albumKey;

  /// 时长字段（数值，单位秒；可缺失）。
  final String durationKey;
  final String coverKey;

  /// 取地址响应中播放链接字段。
  final String playUrlKey;

  /// 歌词请求的歌曲 id 参数名。
  final String lyricsIdParam;

  /// 歌词响应中的歌词内容字段（LRC 或纯文本）。
  final String lyricsKey;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'searchPath': searchPath,
        'playPath': playPath,
        'lyricsPath': lyricsPath,
        'searchKeywordKey': searchKeywordKey,
        'searchListKey': searchListKey,
        'idKey': idKey,
        'titleKey': titleKey,
        'artistKey': artistKey,
        'albumKey': albumKey,
        'durationKey': durationKey,
        'coverKey': coverKey,
        'playIdParam': playIdParam,
        'playUrlKey': playUrlKey,
        'lyricsIdParam': lyricsIdParam,
        'lyricsKey': lyricsKey,
      };

  factory OnlineSourceConfig.fromJson(Map<String, dynamic> json) =>
      OnlineSourceConfig(
        baseUrl: json['baseUrl'] as String? ?? '',
        searchPath: json['searchPath'] as String? ?? '/search',
        playPath: json['playPath'] as String? ?? '/song/url',
        lyricsPath: json['lyricsPath'] as String? ?? '',
        searchKeywordKey: json['searchKeywordKey'] as String? ?? 'keywords',
        searchListKey: json['searchListKey'] as String? ?? 'result',
        idKey: json['idKey'] as String? ?? 'id',
        titleKey: json['titleKey'] as String? ?? 'name',
        artistKey: json['artistKey'] as String? ?? 'artist',
        albumKey: json['albumKey'] as String? ?? 'album',
        durationKey: json['durationKey'] as String? ?? 'duration',
        coverKey: json['coverKey'] as String? ?? 'cover',
        playIdParam: json['playIdParam'] as String? ?? 'id',
        playUrlKey: json['playUrlKey'] as String? ?? 'url',
        lyricsIdParam: json['lyricsIdParam'] as String? ?? 'id',
        lyricsKey: json['lyricsKey'] as String? ?? 'lyric',
      );
}
