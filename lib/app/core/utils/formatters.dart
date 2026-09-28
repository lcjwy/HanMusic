// 通用格式化工具。

/// 时长格式化：mm:ss（超过 1 小时为 h:mm:ss），无效值为 `--:--`。
String formatDuration(Duration? duration) {
  if (duration == null || duration.isNegative) return '--:--';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
