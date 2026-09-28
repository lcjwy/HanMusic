import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/services/timer_service.dart';

TimerService timerWith(List<int> pauseCalls) =>
    TimerService(onPause: () async => pauseCalls.add(pauseCalls.length));

void main() {
  test('倒计时到点仅调用暂停，不清不报错', () {
    fakeAsync((async) {
      final pauseCalls = <int>[];
      final timer = timerWith(pauseCalls);

      timer.startMinutes(1);
      expect(timer.active, isTrue);
      expect(timer.remaining.value, isNotNull);

      async.elapse(const Duration(seconds: 59));
      expect(pauseCalls, isEmpty, reason: '未到点不应暂停');
      expect(timer.remaining.value, const Duration(seconds: 1));

      async.elapse(const Duration(seconds: 2));
      expect(pauseCalls.length, 1, reason: '到点应下发暂停指令');
      expect(timer.active, isFalse, reason: '到点后任务结束');
    });
  });

  test('新设定覆盖旧任务（不产生多次暂停）', () {
    fakeAsync((async) {
      final pauseCalls = <int>[];
      final timer = timerWith(pauseCalls);

      timer.startMinutes(1);
      async.elapse(const Duration(seconds: 10));
      timer.startMinutes(30);
      async.elapse(const Duration(minutes: 1));
      expect(pauseCalls, isEmpty, reason: '旧任务的到点时间应已被覆盖');

      async.elapse(const Duration(minutes: 29, seconds: 1));
      expect(pauseCalls.length, 1);
    });
  });

  test('取消后不再触发暂停', () {
    fakeAsync((async) {
      final pauseCalls = <int>[];
      final timer = timerWith(pauseCalls);

      timer.startMinutes(1);
      async.elapse(const Duration(seconds: 30));
      timer.cancel();
      expect(timer.active, isFalse);

      async.elapse(const Duration(minutes: 2));
      expect(pauseCalls, isEmpty);
    });
  });

  test('顺延 10 分钟：在倒计时上追加时长', () {
    fakeAsync((async) {
      final pauseCalls = <int>[];
      final timer = timerWith(pauseCalls);

      timer.startMinutes(15);
      async.elapse(const Duration(minutes: 14));
      expect(timer.remaining.value, const Duration(minutes: 1));
      timer.extendTenMinutes();
      expect(timer.remaining.value, const Duration(minutes: 11));

      async.elapse(const Duration(minutes: 11, seconds: 1));
      expect(pauseCalls.length, 1);
    });
  });

  test('播完当前歌曲：武装 → 消费返回 true 并解除 → 再次消费返回 false', () {
    fakeAsync((async) {
      final pauseCalls = <int>[];
      final timer = timerWith(pauseCalls);

      timer.startStopAfterCurrent();
      expect(timer.stopAfterCurrent.value, isTrue);
      expect(timer.remaining.value, isNull);

      expect(timer.consumeStopAfterCurrent(), isTrue);
      expect(timer.active, isFalse, reason: '消费即解除');
      expect(timer.consumeStopAfterCurrent(), isFalse);

      async.elapse(const Duration(minutes: 5));
      expect(pauseCalls, isEmpty, reason: '该模式由播放器调用方暂停，服务不主动暂停');
    });
  });

  test('播完当前歌曲模式下顺延 → 转为 10 分钟倒计时', () {
    fakeAsync((async) {
      final pauseCalls = <int>[];
      final timer = timerWith(pauseCalls);

      timer.startStopAfterCurrent();
      timer.extendTenMinutes();

      expect(timer.stopAfterCurrent.value, isFalse);
      expect(timer.remaining.value, const Duration(minutes: 10));

      async.elapse(const Duration(minutes: 10, seconds: 1));
      expect(pauseCalls.length, 1);
    });
  });

  test('预设时长常量符合需求', () {
    expect(TimerService.presetMinutes, [15, 30, 60, 90]);
  });
}
