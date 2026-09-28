/// 全局常量：存储键、通知渠道、默认配置。
abstract final class AppConstants {
  // ---- 持久化键（GetStorage）----
  static const storageContainer = 'han_music';
  static const keySettings = 'settings';
  static const keyLibrary = 'library_index';
  static const keyPlayerState = 'player_state';

  // ---- 后台播放（just_audio_background）----
  static const notificationChannelId = 'com.han.music.han_music.playback';
  static const notificationChannelName = '后台播放';
  static const notificationIcon = 'mipmap/ic_launcher';

  // ---- 本地导入 ----
  /// 支持的音频扩展名（播放后端可解码范围内）。
  static const audioExtensions = ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'aac', 'opus'];

  // ---- 网络源 ----
  static const requestTimeout = Duration(seconds: 30);
}
