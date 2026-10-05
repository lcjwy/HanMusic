import 'dart:math';

import 'package:han_music/app/data/models/play_mode.dart';

/// 纯队列切换逻辑：不依赖播放器实现与 GetX，可独立单元测试。
abstract final class PlayQueueManager {
  /// 当前曲目播完后的自动切换；返回 null 表示按模式自然停止。
  static int? nextAfterComplete({
    required PlayMode mode,
    required int current,
    required int length,
    Random? random,
  }) {
    if (length <= 0 || current < 0 || current >= length) return null;
    switch (mode) {
      case PlayMode.loopOne:
        return current;
      case PlayMode.loopAll:
        return (current + 1) % length;
      case PlayMode.sequential:
        return current + 1 < length ? current + 1 : null;
      case PlayMode.shuffle:
        return _shuffleNext(current, length, random);
    }
  }

  /// 手动"下一曲"：任意模式都取相邻曲目，队尾绕回开头。
  static int nextManual({required int current, required int length}) {
    if (length <= 0) return 0;
    return (current.clamp(0, length - 1) + 1) % length;
  }

  /// 手动"上一曲"：队首绕回结尾。
  static int previousManual({required int current, required int length}) {
    if (length <= 0) return 0;
    return (current.clamp(0, length - 1) - 1 + length) % length;
  }

  /// 队列移除一项后的当前索引：返回 null 表示队列已空。
  /// 当前曲被删时停在该位置（即原下一曲），其余情况补偿位移。
  static int? indexAfterRemoval({
    required int removedIndex,
    required int currentIndex,
    required int lengthBefore,
  }) {
    final lengthAfter = lengthBefore - 1;
    if (lengthAfter <= 0) return null;
    var cur = currentIndex;
    if (removedIndex < cur) {
      cur -= 1;
    } else if (removedIndex == cur) {
      cur = cur.clamp(0, lengthAfter - 1);
    }
    return cur;
  }

  /// 队列移动一项后的当前索引（[movedTo] 为已归一化的目标下标）。
  static int indexAfterMove({
    required int movedFrom,
    required int movedTo,
    required int currentIndex,
  }) {
    if (movedFrom == currentIndex) return movedTo;
    if (movedFrom < currentIndex && movedTo >= currentIndex) {
      return currentIndex - 1;
    }
    if (movedFrom > currentIndex && movedTo <= currentIndex) {
      return currentIndex + 1;
    }
    return currentIndex;
  }

  static int _shuffleNext(int current, int length, Random? random) {
    if (length <= 1) return current;
    final r = random ?? Random();
    var next = r.nextInt(length);
    while (next == current) {
      next = r.nextInt(length);
    }
    return next;
  }
}
