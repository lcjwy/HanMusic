// 平台播放后端差异适配。
//
// 桌面端（Windows/Linux）just_audio 默认后端不可用，需启用 media_kit 后端；
// Web 通过条件导入走空实现。
export 'player_backend_io.dart' if (dart.library.js_interop) 'player_backend_stub.dart';
