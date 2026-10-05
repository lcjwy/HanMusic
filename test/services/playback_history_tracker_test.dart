import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/playback_history_tracker.dart';

void main() {
  test('仅累计播放时间，暂停和缓冲不计时，每次装载只提交一次', () {
    fakeAsync((async) {
      final commits = <Song>[];
      final song = Song.fromLocalFile(path: '/a.mp3');
      final tracker = PlaybackHistoryTracker(
        delay: const Duration(seconds: 10),
        onCommit: commits.add,
      );
      tracker.reset(song);
      tracker.update(active: true);
      async.elapse(const Duration(seconds: 4));
      tracker.update(active: false);
      async.elapse(const Duration(minutes: 1));
      expect(commits, isEmpty);
      tracker.update(active: true);
      async.elapse(const Duration(seconds: 5));
      tracker.update(active: false);
      async.elapse(const Duration(minutes: 1));
      expect(commits, isEmpty);
      tracker.update(active: true);
      async.elapse(const Duration(seconds: 1));
      expect(commits, [song]);
      tracker.update(active: false);
      tracker.update(active: true);
      async.elapse(const Duration(minutes: 1));
      expect(commits, [song]);
      tracker.dispose();
    });
  });

  test('切歌、装载失败和销毁取消旧歌曲计时', () {
    fakeAsync((async) {
      final commits = <Song>[];
      final a = Song.fromLocalFile(path: '/a.mp3');
      final b = Song.fromLocalFile(path: '/b.mp3');
      final tracker = PlaybackHistoryTracker(
        delay: const Duration(seconds: 10),
        onCommit: commits.add,
      );
      tracker.reset(a);
      tracker.update(active: true);
      async.elapse(const Duration(seconds: 9));
      tracker.reset();
      tracker.update(active: true);
      async.elapse(const Duration(seconds: 20));
      expect(commits, isEmpty);
      tracker.reset(b);
      tracker.update(active: true);
      async.elapse(const Duration(seconds: 10));
      expect(commits, [b]);
      tracker.reset(a);
      tracker.update(active: true);
      tracker.dispose();
      async.elapse(const Duration(minutes: 1));
      expect(commits, [b]);
    });
  });
}
