import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/core/platform/player_backend.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/core/storage/secret_store.dart';
import 'package:han_music/app/core/theme/app_theme.dart';
import 'app/data/models/song.dart';
import 'app/data/sources/local/local_lyrics.dart';
import 'app/routes/app_pages.dart';
import 'app/services/ai_service.dart';
import 'app/services/library_import_service.dart';
import 'app/services/library_service.dart';
import 'app/services/lyrics_service.dart';
import 'app/services/online_source_service.dart';
import 'app/services/player_service.dart';
import 'app/services/playlist_service.dart';
import 'app/services/settings_service.dart';
import 'app/services/timer_service.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = GetStorageStore(container: AppConstants.storageContainer);
  await store.init();

  initPlayerBackend();

  final settings = Get.put(SettingsService(store), permanent: true);
  await settings.load();
  final library = Get.put(LibraryService(store), permanent: true);
  await library.load();
  Get.put(LibraryImportService(library), permanent: true);
  final playlists = Get.put(PlaylistService(store), permanent: true);
  await playlists.load();
  final onlineSource = Get.put(OnlineSourceService(), permanent: true);
  final ai = Get.put(AiService(SecureSecretStore()), permanent: true);
  await ai.init();
  final lyrics = Get.put(
    LyricsService(
      store,
      readEmbedded: readEmbeddedLyrics,
      readSourceLyrics: (song) async => song.source == SongSource.online
          ? await onlineSource.resolveLyrics(song)
          : null,
      isAiConfigured: () {
        final config = settings.ai.value;
        return config != null && ai.hasKey(config.provider);
      },
      fetchAiLyrics: (song) => ai.fetchLyrics(
        title: song.title,
        artist: song.artist,
        album: song.album,
      ),
    ),
    permanent: true,
  );
  final player = Get.put(
    PlayerService(
      store,
      settings,
      urlResolver: onlineSource.resolveForPlayer,
      lyricsResolver: lyrics.resolve,
    ),
    permanent: true,
  );
  await player.init();
  final timer = Get.put(TimerService(onPause: player.pause), permanent: true);
  player.stopAfterCurrentHook = timer.consumeStopAfterCurrent;

  if (backgroundAudioSupported) {
    await JustAudioBackground.init(
      androidNotificationChannelId: AppConstants.notificationChannelId,
      androidNotificationChannelName: AppConstants.notificationChannelName,
      androidNotificationOngoing: true,
    );
  }
  runApp(buildApp());
}

/// 根组件：主题模式响应式绑定设置服务；转场统一丝滑（≤300ms）。
Widget buildApp() {
  final settings = Get.find<SettingsService>();
  return Obx(
    () => GetMaterialApp(
      title: 'HanMusic',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode.value.toFlutterMode(),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
    ),
  );
}
