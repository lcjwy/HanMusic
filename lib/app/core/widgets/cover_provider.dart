// 本地封面文件 → ImageProvider 的平台适配（Web 编译走空实现）。
export 'cover_provider_io.dart'
    if (dart.library.js_interop) 'cover_provider_stub.dart';
