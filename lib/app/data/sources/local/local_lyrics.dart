// 音频文件内嵌歌词读取：隔离 dart:io，Web 端编译走空实现。
export 'local_lyrics_io.dart' if (dart.library.js_interop) 'local_lyrics_stub.dart';
