import 'dart:async';

import 'package:clock/clock.dart';
import 'package:get/get.dart';

/// 睡眠定时服务：与播放器完全解耦，到点仅下发"暂停"指令。
///
/// 按 `clock.now()` 墙钟时间计算剩余（设备休眠唤醒后依然准确；测试环境
/// 可被 fake_async 模拟）。同一时间只允许一个任务，新设定覆盖旧任务。
class TimerService extends GetxService {
  TimerService({required Future<void> Function() onPause})
      : _onPause = onPause;

  final Future<void> Function() _onPause;

  /// 剩余时间（null 表示无倒计时任务）。
  final remaining = Rxn<Duration>();

  /// "播完当前歌曲后停止"模式。
  final stopAfterCurrent = false.obs;

  static const presetMinutes = [15, 30, 60, 90];

  Timer? _ticker;
  DateTime? _deadline;

  bool get active => remaining.value != null || stopAfterCurrent.value;

  /// 启动倒计时（分钟），覆盖既有任务。
  void startMinutes(int minutes) {
    _clear();
    _deadline = clock.now().add(Duration(minutes: minutes));
    remaining.value = _deadline!.difference(clock.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// 启动"播完当前歌曲后停止"，覆盖既有任务。
  void startStopAfterCurrent() {
    _clear();
    stopAfterCurrent.value = true;
  }

  /// 顺延 10 分钟：倒计时任务追加时长；"播完当前歌曲"任务转为 10 分钟倒计时。
  void extendTenMinutes() {
    if (_deadline != null) {
      _deadline = _deadline!.add(const Duration(minutes: 10));
      remaining.value = _deadline!.difference(clock.now());
    } else if (stopAfterCurrent.value) {
      startMinutes(10);
    }
  }

  /// 取消当前任务。
  void cancel() => _clear();

  /// "播完当前歌曲后停止"的消费入口（由播放器播完时调用）：
  /// 已武装则解除并返回 true，调用方应暂停播放。
  bool consumeStopAfterCurrent() {
    if (!stopAfterCurrent.value) return false;
    stopAfterCurrent.value = false;
    return true;
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final left = deadline.difference(clock.now());
    if (left <= Duration.zero) {
      _clear();
      // 暂停指令的失败无需阻断定时结束；显式标记忽略避免悬挂 rejection
      unawaited(_onPause());
    } else {
      remaining.value = left;
    }
  }

  void _clear() {
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
    remaining.value = null;
    stopAfterCurrent.value = false;
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }
}
