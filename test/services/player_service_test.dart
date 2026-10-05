import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/services/player_service.dart';
import 'package:han_music/app/services/settings_service.dart';
import 'package:just_audio/just_audio.dart';

class TestAudioPlayer extends Fake implements AudioPlayer {
  final _states = StreamController<PlayerState>.broadcast(sync: true);
  PlayerState _state = PlayerState(false, ProcessingState.idle);
  Completer<void>? _playCompleted;

  @override
  bool get playing => _state.playing;
  @override
  ProcessingState get processingState => _state.processingState;
  @override
  Stream<PlayerState> get playerStateStream => _states.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;

  void emit(bool playing, ProcessingState processing) {
    _state = PlayerState(playing, processing);
    _states.add(_state);
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    await pause();
    emit(false, ProcessingState.ready);
    return null;
  }

  @override
  Future<void> play() {
    _playCompleted ??= Completer<void>();
    emit(true, ProcessingState.ready);
    return _playCompleted!.future;
  }

  @override
  Future<void> pause() async {
    emit(false, processingState);
    _playCompleted?.complete();
    _playCompleted = null;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    await pause();
    await _states.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          null,
        );
  });

  PlayerService build(MemoryStore store, TestAudioPlayer audio) =>
      PlayerService(store, SettingsService(store), playerFactory: () => audio);
  final songs = [
    Song.fromLocalFile(path: '/a.mp3'),
    Song.fromLocalFile(path: '/b.mp3'),
    Song.fromLocalFile(path: '/c.mp3'),
  ];

  test('播放器在 play Future 未完成时提交历史，暂停和缓冲不计时', () async {
    final audio = TestAudioPlayer();
    final player = build(MemoryStore(), audio);
    final commits = <Song>[];
    player.playbackCommitted = commits.add;
    await AudioSession.instance;
    fakeAsync((async) {
      unawaited(player.init());
      async.flushMicrotasks();
      unawaited(player.playQueue(songs));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 4));
      audio.emit(true, ProcessingState.buffering);
      async.elapse(const Duration(seconds: 20));
      expect(commits, isEmpty);
      audio.emit(true, ProcessingState.ready);
      async.elapse(const Duration(seconds: 5));
      unawaited(player.pause());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 20));
      expect(commits, isEmpty);
      unawaited(player.togglePlayPause());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      expect(commits, [songs.first]);
      player.onClose();
      async.flushMicrotasks();
    });
  });

  for (final operation in ['removeCurrent', 'removeBefore', 'moveCurrent']) {
    test('队列 $operation 后重启恢复同一当前曲和正确队列', () async {
      final store = MemoryStore();
      final player = build(store, TestAudioPlayer());
      await player.init();
      unawaited(player.playQueue(songs, initialIndex: 1));
      await Future<void>.delayed(Duration.zero);
      await player.pause();
      if (operation == 'removeCurrent') {
        unawaited(player.removeFromQueue(1));
        await Future<void>.delayed(Duration.zero);
        await player.pause();
      } else if (operation == 'removeBefore') {
        await player.removeFromQueue(0);
      } else {
        await player.moveInQueue(1, 3);
      }
      final expectedQueue = player.queue.map((s) => s.id).toList();
      final expectedCurrent = player.current.value!.id;
      final expectedIndex = player.currentIndex.value;
      player.onClose();
      final restored = build(store, TestAudioPlayer());
      await restored.init();
      expect(restored.queue.map((s) => s.id), expectedQueue);
      expect(restored.current.value?.id, expectedCurrent);
      expect(restored.currentIndex.value, expectedIndex);
      restored.onClose();
    });
  }
}
