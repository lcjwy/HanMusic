// 应用封面目录的文件写入适配：隔离 dart:io，Web 端编译走空实现。
export 'cover_store_io.dart' if (dart.library.js_interop) 'cover_store_stub.dart';
