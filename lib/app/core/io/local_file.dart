// 本地文件能力适配：隔离 dart:io，Web 端编译走空实现。
export 'local_file_io.dart' if (dart.library.js_interop) 'local_file_stub.dart';
