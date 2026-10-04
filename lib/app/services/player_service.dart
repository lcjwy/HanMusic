import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:audio_session/audio_session.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/data/models/play_mode.dart';
import 'package:han_music/app/data/models/song.dart';
import 'package:han_music/app/core/utils/lyrics.dart';
import 'package:han_music/app/services/lyrics_service.dart';
import 'package:han_music/app/services/play_queue_manager.dart';
import 'package:han_music/app/services/settings_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// 全局播放器服务：封装 just_audio，对上层只暴露 Rx 状态与方法。
///
/// 本地文件与网络流同一入口，来源差异不外泄；队列切换由
/// [PlayQueueManager] 纯逻辑驱动；just_audio_background 负责通知栏与
/// 系统媒体中心的控制集成。
class PlayerService extends GetxService {
  PlayerService(
    this._store,
    this._settings, {
    Future<String> Function(Song song)? urlResolver,
    LyricsResolver? lyricsResolver,
  })  : _urlResolver = urlResolver,
        _lyricsResolver = lyricsResolver;

  final KeyValueStore _store;
  final SettingsService _settings;

  /// 在线歌曲播放地址解析器（由 OnlineSourceService 提供）。
  final Future<String> Function(Song song)? _urlResolver;

  /// 歌词解析器（由 LyricsService 提供：缓存→内嵌→网络源→AI 链路）。
  final LyricsResolver? _lyricsResolver;

  late final AudioPlayer _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  // ---- 对上暴露的响应式状态 ----
  final queue = <Song>[].obs;
  final currentIndex = (-1).obs;
  final current = Rxn<Song>();
  final playing = false.obs;
  final buffering = false.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final playMode = PlayMode.sequential.obs;
  final volume = 1.0.obs;

  /// 最近一次播放错误的用户可读文案；UI 展示后置回 null。
  final lastError = Rxn<String>();

  /// 当前歌曲的歌词（解析失败/无歌词为 null，UI 展示占位）。
  final lyrics = Rxn<LyricsDocument>();

  /// 当前歌词是否来自 AI（播放页展示来源标识）。
  final lyricsFromAi = false.obs;

  /// 歌词装载序号：切歌后旧结果晚到直接丢弃。
  int _lyricsSeq = 0;

  /// 已装载音源的歌曲 id（区分"恢复上次播放后首次点播"与常规暂停续播）。
  String? _loadedSongId;

  /// 恢复播放使用的记忆进度。
  Duration? _resumePosition;

  /// 装载序号：每次装载自增；await 之后校验，过期装载直接放弃。
  /// 防止快速连点/上一曲下一曲时，滞留的旧装载覆盖新播放
  /// （界面显示与实际出声不同歌），以及装载被打断被误判为播放失败。
  int _loadSeq = 0;

  /// "播完当前歌曲后停止"钩子（由定时服务注入）：返回 true 时播完不再
  /// 自动切歌。与 TimerService 保持单向依赖，避免服务互相引用。
  bool Function()? stopAfterCurrentHook;

  /// 连续失败计数：一轮队列内全部失败则停止自动跳过，避免死循环。
  int _consecutiveFailures = 0;

  Future<void> init() async {
    _player = AudioPlayer();

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // 拔出耳机自动暂停；来电等中断由音乐场景配置自动处理。
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) => _player.pause()),
      );
    } on Exception {
      // 音频会话配置失败不阻断播放
    }

    _subscriptions.addAll([
      _player.positionStream.listen((p) => position.value = p),
      _player.durationStream.listen((d) {
        if (d != null) duration.value = d;
      }),
      _player.playerStateStream.listen(_onPlayerState),
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) => _reportError('播放出错，请重试'),
      ),
    ]);

    await _restore();
  }

  void _onPlayerState(PlayerState state) {
    playing.value = state.playing;
    buffering.value = state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
    if (state.processingState == ProcessingState.completed) {
      unawaited(_handleCompleted());
    }
  }

  /// 播完处理：睡眠定时钩子 > 单曲循环回卷 > 按模式切换/自然停止。
  Future<void> _handleCompleted() async {
    final hook = stopAfterCurrentHook;
    if (hook != null && hook()) {
      // 睡眠定时"播完当前歌曲后停止"：到点暂停，不切歌。
      await _player.pause();
      // 整曲已播完，记忆进度归零——若存整曲时长，恢复播放会从曲尾
      // 起播并瞬时再次触发 completed，表现为点播放直接跳歌/无声暂停
      _resumePosition = Duration.zero;
      await _persistState();
      return;
    }
    if (playMode.value == PlayMode.loopOne && queue.isNotEmpty) {
      // 单曲循环复用已装载音源，回卷重播即可；重新装载会让在线流重复缓冲
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    final next = PlayQueueManager.nextAfterComplete(
      mode: playMode.value,
      current: currentIndex.value,
      length: queue.length,
    );
    if (next != null) {
      await playAt(next);
    } else {
      // 自然播完：暂停在队尾，避免"播完仍显示播放中"的状态不一致；
      // 进度归零，恢复播放时重播当前曲而非从曲尾瞬时 completed
      await _player.pause();
      _resumePosition = Duration.zero;
      await _persistState();
    }
  }

  /// 以 [songs] 作为新队列，从 [initialIndex] 开始播放。
  Future<void> playQueue(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    queue.assignAll(songs);
    // 新队列重置连续失败计数，避免旧队列的失败记录让新队列
    // 首次失败就达到"整轮失败"阈值而失去自动跳过
    _consecutiveFailures = 0;
    await _persistQueue();
    await playAt(initialIndex.clamp(0, songs.length - 1));
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.length) return;
    currentIndex.value = index;
    final song = queue[index];
    current.value = song;
    _resumePosition = null;
    await _persistState();
    await _loadAndPlay(song);
  }

  Future<void> _loadAndPlay(Song song, {Duration? startAt}) async {
    final seq = ++_loadSeq;
    lyrics.value = null; // 切歌即清旧歌词，避免展示上一首内容
    try {
      final playable = await _ensurePlayable(song);
      if (seq != _loadSeq) return;
      final uri = playable.source == SongSource.local
          ? Uri.file(playable.pathOrUrl)
          : Uri.tryParse(playable.pathOrUrl) ?? Uri();
      final source = AudioSource.uri(uri, tag: _mediaItem(playable));
      buffering.value = true;
      await _player.setAudioSource(source, initialPosition: startAt);
      if (seq != _loadSeq) return;
      _loadedSongId = playable.id;
      _consecutiveFailures = 0;
      unawaited(_loadLyrics(playable));
      await _player.play();
    } on AppException catch (e) {
      if (seq != _loadSeq) return;
      buffering.value = false;
      _consecutiveFailures++;
      final skipped = await _skipOnFailure();
      // 自动跳过链路中不逐曲弹错（避免刷屏），跳过结束后呈现最后一次错误
      if (!skipped) lastError.value = e.message;
    } on Exception catch (e) {
      if (seq != _loadSeq) return;
      // 被更新的装载打断属于正常切换，不计入播放失败
      if (e is PlayerInterruptedException) return;
      buffering.value = false;
      _consecutiveFailures++;
      final skipped = await _skipOnFailure();
      if (!skipped) _reportError('无法播放「${song.title}」', e);
    }
  }

  /// 装载当前歌曲歌词（链路在 LyricsService）；失败静默降级占位。
  Future<void> _loadLyrics(Song song, {bool forceRefresh = false}) async {
    final seq = ++_lyricsSeq;
    ResolvedLyrics? resolved;
    try {
      resolved = await _lyricsResolver?.call(song, forceRefresh: forceRefresh);
    } on Exception {
      resolved = null;
    }
    if (seq != _lyricsSeq) return;
    lyrics.value = resolved?.document;
    lyricsFromAi.value = resolved?.fromAi ?? false;
  }

  /// 重新获取当前歌曲歌词（AI 结果可被覆盖，手动粘贴保留）。
  Future<void> refreshLyrics() async {
    final song = current.value;
    if (song == null) return;
    await _loadLyrics(song, forceRefresh: true);
  }

  /// 在线歌曲且地址未解析时经 resolver 获取，解析结果回写队列缓存。
  Future<Song> _ensurePlayable(Song song) async {
    if (song.source != SongSource.online ||
        song.pathOrUrl.isNotEmpty ||
        _urlResolver == null) {
      return song;
    }
    final url = await _urlResolver(song);
    final resolved = song.copyWith(pathOrUrl: url);
    final index = queue.indexOf(song);
    if (index >= 0) queue[index] = resolved;
    if (current.value?.id == song.id) current.value = resolved;
    return resolved;
  }

  /// 播放失败自动跳过（设置可关）：顺序跳下一曲，整轮失败则停下。
  /// 返回是否已继续跳过；未跳过时由调用方负责呈现错误。
  Future<bool> _skipOnFailure() async {
    if (!_settings.autoSkipOnFail.value ||
        queue.length <= 1 ||
        _consecutiveFailures >= queue.length) {
      return false;
    }
    final next = PlayQueueManager.nextAfterComplete(
      mode: PlayMode.sequential,
      current: currentIndex.value,
      length: queue.length,
    );
    if (next == null || next == currentIndex.value) return false;
    currentIndex.value = next;
    current.value = queue[next];
    await _persistState();
    await _loadAndPlay(queue[next]);
    return true;
  }

  MediaItem _mediaItem(Song song) {
    final cover = song.coverUrl;
    Uri? artUri;
    if (cover != null && cover.isNotEmpty) {
      artUri =
          cover.startsWith('http') ? Uri.tryParse(cover) : Uri.file(cover);
    }
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist == Song.defaultArtist ? null : song.artist,
      album: song.album == Song.defaultAlbum ? null : song.album,
      duration: song.duration,
      artUri: artUri,
    );
  }

  void _reportError(String message, [Object? cause]) {
    // cause 仅用于排查，不上抛、不展示
    lastError.value = message;
  }

  /// 播放/暂停。恢复上次播放时先装载音源并从记忆进度开始。
  Future<void> togglePlayPause() async {
    final song = current.value;
    if (song == null) return;
    if (_loadedSongId != song.id) {
      await _loadAndPlay(song, startAt: _resumePosition);
      return;
    }
    if (_player.playing) {
      await _player.pause();
      _resumePosition = _player.position;
      await _persistState();
    } else {
      await _player.play();
    }
  }

  /// 外部指令（如睡眠定时）：仅暂停，不清队列与进度。
  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    await playAt(
      PlayQueueManager.nextManual(
        current: currentIndex.value,
        length: queue.length,
      ),
    );
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    await playAt(
      PlayQueueManager.previousManual(
        current: currentIndex.value,
        length: queue.length,
      ),
    );
  }

  Future<void> seek(Duration target) => _player.seek(target);

  Future<void> setPlayMode(PlayMode mode) async {
    playMode.value = mode;
    await _persistState();
  }

  /// 实时调音量（不持久化；持久化随其他状态变更一起落盘）。
  Future<void> setVolume(double value) async {
    volume.value = value.clamp(0.0, 1.0);
    await _player.setVolume(volume.value);
  }

  Future<void> _restore() async {
    try {
      final queueRaw = _store.read<String>(AppConstants.keyPlayerQueue);
      final stateRaw = _store.read<String>(AppConstants.keyPlayerState);
      // 旧版本把队列内嵌在 state 键中：读出后迁移为分键存储
      final legacy = queueRaw == null || queueRaw.isEmpty;
      final queueJsonRaw = legacy ? stateRaw : queueRaw;
      if (queueJsonRaw == null || queueJsonRaw.isEmpty) return;

      final queueJson = jsonDecode(queueJsonRaw) as Map<String, dynamic>;
      // 播放位置类状态：新格式在 state 键；旧格式与队列同键
      var stateJson = queueJson;
      if (!legacy && stateRaw != null && stateRaw.isNotEmpty) {
        stateJson = jsonDecode(stateRaw) as Map<String, dynamic>;
      }

      playMode.value = PlayMode.values.firstWhere(
        (m) => m.name == stateJson['mode'],
        orElse: () => PlayMode.sequential,
      );
      volume.value = ((stateJson['volume'] as num?) ?? 1.0).clamp(0.0, 1.0).toDouble();
      // 恢复的音量要真正应用到播放器，而不仅是 UI 状态
      await _player.setVolume(volume.value);

      final list = _songsFromJson(queueJson['queue']);
      if (legacy && list.isNotEmpty) {
        await _persistQueue(list);
      }
      queue.assignAll(list);
      final index = stateJson['index'] as int? ?? -1;
      if (index >= 0 && index < queue.length) {
        currentIndex.value = index;
        current.value = queue[index];
        _resumePosition =
            Duration(milliseconds: stateJson['positionMs'] as int? ?? 0);
        duration.value = queue[index].duration ?? Duration.zero;
        // 音源未装载：首次点播时从记忆进度开始
        _loadedSongId = null;
      }
    } on FormatException {
      // 状态损坏时从零开始
    } on TypeError {
      // 字段类型损坏同理，不阻断启动
    }
  }

  List<Song> _songsFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Song.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// 播放位置类状态（索引/模式/进度/音量），切歌、暂停等高频路径写入。
  Future<void> _persistState() async {
    final json = {
      'index': currentIndex.value,
      'mode': playMode.value.name,
      'positionMs': (_resumePosition ?? _player.position).inMilliseconds,
      'volume': volume.value,
    };
    await _store.write(AppConstants.keyPlayerState, jsonEncode(json));
  }

  /// 播放队列（可达数千首），仅在队列组合变化时写入，
  /// 避免高频路径上每次全量 JSON 编码造成主线程卡顿。
  Future<void> _persistQueue([List<Song>? songs]) async {
    final list = songs ?? queue;
    final json = {'queue': list.map((s) => s.toJson()).toList()};
    await _store.write(AppConstants.keyPlayerQueue, jsonEncode(json));
  }

  @override
  void onClose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.onClose();
  }
}
