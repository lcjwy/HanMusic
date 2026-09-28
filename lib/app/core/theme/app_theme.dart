import 'package:flutter/material.dart';
import 'package:han_music/app/data/models/app_settings.dart';

/// 应用主题：单一种子色生成亮/暗两套，保持 Material 3 默认风格。
abstract final class AppTheme {
  static const seedColor = Color(0xFF3F51B5);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}

/// AppThemeMode → Flutter ThemeMode（UI 层映射，模型层保持纯净）。
extension AppThemeModeMapper on AppThemeMode {
  ThemeMode toFlutterMode() => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}
