import 'package:flutter/material.dart';
import 'package:han_music/app/data/models/app_settings.dart';

/// 应用主题：单一种子色生成亮/暗两套，保持 Material 3 默认风格。
///
/// 种子色偏年轻化（明快的紫罗兰系）；暗色 surface 显式深灰，
/// 不使用纯黑背景（见架构文档 4.8）。
abstract final class AppTheme {
  static const seedColor = Color(0xFF7C5CFC);

  /// 炫彩辅助色：渐变进度条、极光背景、导航高亮共用。
  static const accentPink = Color(0xFFF06292);
  static const accentCyan = Color(0xFF26C6DA);

  /// 渐变进度条统一配色（紫→浅紫→粉）。
  static const progressGradient = [seedColor, Color(0xFFB388FF), accentPink];

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
      // 水花飞溅式按压缩放，配合整体年轻化观感
      splashFactory: InkSparkle.splashFactory,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: tuned.primary.withValues(alpha: 0.14),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: tuned.primary.withValues(alpha: 0.14),
      ),
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
