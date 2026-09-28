// 本地扫描与元数据读取适配：隔离 dart:io 与原生插件，Web 编译走空实现。
export 'local_importer_io.dart'
    if (dart.library.js_interop) 'local_importer_stub.dart';
