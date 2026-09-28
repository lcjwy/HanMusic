import 'package:flutter/material.dart';

/// 播放模式。
enum PlayMode {
  /// 顺序播放：播至队尾自然停止。
  sequential,

  /// 列表循环。
  loopAll,

  /// 单曲循环。
  loopOne,

  /// 随机播放（不与上一首重复）。
  shuffle,
}

/// 播放模式在 UI 上的图标与文案。
extension PlayModeX on PlayMode {
  IconData get icon => switch (this) {
        PlayMode.sequential => Icons.playlist_play,
        PlayMode.loopAll => Icons.repeat,
        PlayMode.loopOne => Icons.repeat_one,
        PlayMode.shuffle => Icons.shuffle,
      };

  String get label => switch (this) {
        PlayMode.sequential => '顺序播放',
        PlayMode.loopAll => '列表循环',
        PlayMode.loopOne => '单曲循环',
        PlayMode.shuffle => '随机播放',
      };
}
