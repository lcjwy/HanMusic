import 'dart:async';

import 'package:clock/clock.dart';
import 'package:han_music/app/data/models/song.dart';

/// 仅累计实际出声状态的时间，暂停、缓冲与装载期间不计时。
class PlaybackHistoryTracker {
  PlaybackHistoryTracker({required this.delay, required this.onCommit});

  final Duration delay;
  final void Function(Song song) onCommit;
  final Stopwatch _elapsed = clock.stopwatch();
  Timer? _timer;
  Song? _song;
  bool _committed = false;

  void reset([Song? song]) {
    _timer?.cancel();
    _timer = null;
    _elapsed.stop();
    _elapsed.reset();
    _song = song;
    _committed = false;
  }

  void update({required bool active}) {
    _timer?.cancel();
    _timer = null;
    _elapsed.stop();
    final song = _song;
    if (!active || song == null || _committed) return;
    _elapsed.start();
    final remaining = delay - _elapsed.elapsed;
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      _elapsed.stop();
      _committed = true;
      onCommit(song);
    });
  }

  void dispose() => reset();
}
