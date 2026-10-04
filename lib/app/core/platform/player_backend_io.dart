import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// 初始化 media_kit 播放后端：内部仅在 Windows/Linux 上生效，其余平台跳过。
void initPlayerBackend() {
  JustAudioMediaKit.ensureInitialized();
}

/// Android/iOS/macOS/Web 支持后台播放与系统媒体控制；
/// 桌面端窗口常驻即可满足，不走 audio_service。
bool get backgroundAudioSupported =>
    !(Platform.isWindows || Platform.isLinux);
