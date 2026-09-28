/// 统一业务异常：Service/Repository 层抛出，UI 层捕获后转为用户可读提示。
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// 用户可读的提示文案。
  final String message;

  /// 原始异常，仅供日志排查，不直接展示。
  final Object? cause;

  @override
  String toString() => 'AppException: $message${cause == null ? '' : ' ($cause)'}';
}
