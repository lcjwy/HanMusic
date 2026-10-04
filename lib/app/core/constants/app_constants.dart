/// 全局常量：存储键、通知渠道、默认配置。
abstract final class AppConstants {
  // ---- 持久化键（GetStorage）----
  static const storageContainer = 'han_music';
  static const keySettings = 'settings';
  static const keyLibrary = 'library_index';
  static const keyPlayerState = 'player_state';

  /// 播放队列与播放位置分键存储：队列大且仅在组合变化时写入，
  /// 位置类状态高频写入，避免每次全量序列化队列。
  static const keyPlayerQueue = 'player_queue';

  // ---- 后台播放（just_audio_background）----
  static const notificationChannelId = 'com.han.music.han_music.playback';
  static const notificationChannelName = '后台播放';

  // ---- 本地导入 ----
  /// 支持的音频扩展名（播放后端可解码范围内）。
  static const audioExtensions = ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'aac', 'opus'];

  // ---- 本地封面 ----
  /// 封面存在性缓存上限（按访问序淘汰最久未用条目）。
  static const coverCacheLimit = 2048;

  // ---- 网络源 ----
  static const requestTimeout = Duration(seconds: 30);

  /// 在线搜索输入防抖时长。
  static const searchDebounce = Duration(milliseconds: 500);

  // ---- 歌单 ----
  static const keyPlaylists = 'playlists';
  static const favoritePlaylistId = 'fav';
  static const favoritePlaylistName = '我喜欢的音乐';

  // ---- 应用信息 ----
  static const appVersion = '0.2.0';
}
