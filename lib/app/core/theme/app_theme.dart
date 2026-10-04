import 'package:flutter/material.dart';
import 'package:han_music/app/data/models/app_settings.dart';

/// 应用主题：单一种子色生成亮/暗两套，保持 Material 3 默认风格。
///
/// 种子色偏年轻化（明快的紫罗兰系）；暗色 surface 显式深灰，
/// 不使用纯黑背景（见架构文档 4.8）。
abstract final class AppTheme {
  static const seedColor = Color(0xFF7C5CFC);

  /// 暗色模式表面色：深灰紫调，替代 M3 默认的近黑背景。
  static const _darkSurface = Color(0xFF1C1A24);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final tuned = isDark
        ? colorScheme.copyWith(surface: _darkSurface)
        : colorScheme;
    return ThemeData(
      colorScheme: tuned,
      scaffoldBackgroundColor:
          isDark ? _darkSurface : null,
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
