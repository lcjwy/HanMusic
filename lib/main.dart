import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/constants/app_routes.dart';
import 'package:han_music/app/core/platform/player_backend.dart';
import 'package:han_music/app/core/storage/key_value_store.dart';
import 'package:han_music/app/core/theme/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'app/services/library_service.dart';
import 'app/services/player_service.dart';
import 'app/services/settings_service.dart';
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
  final player = Get.put(PlayerService(store, settings), permanent: true);
  await player.init();

  if (backgroundAudioSupported) {
    await JustAudioBackground.init(
      androidNotificationChannelId: AppConstants.notificationChannelId,
      androidNotificationChannelName: AppConstants.notificationChannelName,
      androidNotificationOngoing: true,
    );
  }
  runApp(buildApp());
}

/// 根组件：主题模式响应式绑定设置服务。
Widget buildApp() {
  final settings = Get.find<SettingsService>();
  return Obx(
    () => GetMaterialApp(
      title: 'HanMusic',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode.value.toFlutterMode(),
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
    ),
  );
}
