import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/data/models/play_mode.dart';
import 'package:han_music/app/services/play_queue_manager.dart';

void main() {
  group('nextAfterComplete（自动切歌）', () {
    test('顺序播放：播完队尾自然停止（返回 null）', () {
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.sequential,
          current: 0,
          length: 3,
        ),
        1,
      );
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.sequential,
          current: 2,
          length: 3,
        ),
        isNull,
      );
    });

    test('列表循环：队尾绕回队首', () {
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.loopAll,
          current: 2,
          length: 3,
        ),
        0,
      );
    });

    test('单曲循环：始终停在当前曲', () {
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.loopOne,
          current: 1,
          length: 3,
        ),
        1,
      );
    });

    test('随机播放：不与上一首重复（队列 >= 2）', () {
      final random = Random(42);
      for (var i = 0; i < 50; i++) {
        final next = PlayQueueManager.nextAfterComplete(
          mode: PlayMode.shuffle,
          current: 1,
          length: 3,
          random: random,
        )!;
        expect(next, isNot(1));
        expect(next, inInclusiveRange(0, 2));
      }
    });

    test('单曲队列：顺序播放自然停止；随机/循环保持当前曲', () {
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.sequential,
          current: 0,
          length: 1,
        ),
        isNull,
      );
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.shuffle,
          current: 0,
          length: 1,
        ),
        0,
      );
    });

    test('空队列与越界索引返回 null', () {
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.loopAll,
          current: 0,
          length: 0,
        ),
        isNull,
      );
      expect(
        PlayQueueManager.nextAfterComplete(
          mode: PlayMode.loopAll,
          current: 5,
          length: 3,
        ),
        isNull,
      );
    });
  });

  group('手动切歌', () {
    test('下一曲在队尾绕回队首', () {
      expect(PlayQueueManager.nextManual(current: 0, length: 3), 1);
      expect(PlayQueueManager.nextManual(current: 2, length: 3), 0);
    });

    test('上一曲在队首绕回队尾', () {
      expect(PlayQueueManager.previousManual(current: 0, length: 3), 2);
      expect(PlayQueueManager.previousManual(current: 1, length: 3), 0);
    });

    test('空队列与越界索引安全处理', () {
      expect(PlayQueueManager.nextManual(current: -1, length: 0), 0);
      expect(PlayQueueManager.previousManual(current: -1, length: 3), 2);
    });
  });

  group('队列移除后的当前索引', () {
    test('删除在当前曲之前 → 当前索引前移', () {
      expect(
        PlayQueueManager.indexAfterRemoval(
          removedIndex: 0,
          currentIndex: 2,
          lengthBefore: 5,
        ),
        1,
      );
    });

    test('删除当前曲 → 停在该位置（原下一曲）', () {
      expect(
        PlayQueueManager.indexAfterRemoval(
          removedIndex: 2,
          currentIndex: 2,
          lengthBefore: 5,
        ),
        2,
      );
    });

    test('删除当前曲且为队尾 → 回退到新队尾', () {
      expect(
        PlayQueueManager.indexAfterRemoval(
          removedIndex: 4,
          currentIndex: 4,
          lengthBefore: 5,
        ),
        3,
      );
    });

    test('删除在当前曲之后 → 当前索引不变', () {
      expect(
        PlayQueueManager.indexAfterRemoval(
          removedIndex: 3,
          currentIndex: 1,
          lengthBefore: 5,
        ),
        1,
      );
    });

    test('队列清空 → 返回 null', () {
      expect(
        PlayQueueManager.indexAfterRemoval(
          removedIndex: 0,
          currentIndex: 0,
          lengthBefore: 1,
        ),
        isNull,
      );
    });
  });

  group('队列移动后的当前索引', () {
    test('移动的就是当前曲 → 跟随到新位置', () {
      expect(
        PlayQueueManager.indexAfterMove(
          movedFrom: 4,
          movedTo: 0,
          currentIndex: 4,
        ),
        0,
      );
    });

    test('当前曲在移动目标之后且源在其前 → 前移一位', () {
      expect(
        PlayQueueManager.indexAfterMove(
          movedFrom: 0,
          movedTo: 3,
          currentIndex: 1,
        ),
        0,
      );
    });

    test('当前曲在源与目标之间 → 后移一位', () {
      expect(
        PlayQueueManager.indexAfterMove(
          movedFrom: 4,
          movedTo: 0,
          currentIndex: 2,
        ),
        3,
      );
    });

    test('移动不跨越当前曲 → 不变', () {
      expect(
        PlayQueueManager.indexAfterMove(
          movedFrom: 3,
          movedTo: 4,
          currentIndex: 1,
        ),
        1,
      );
    });
  });
}
