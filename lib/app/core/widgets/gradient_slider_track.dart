import 'package:flutter/material.dart';

/// 渐变滑条轨道：已播段用主题渐变着色，未播段沿用 inactive 轨道色。
///
/// 按 RoundedRectSliderTrackShape 的绘制结构实现（含活动段加高
/// additionalActiveTrackHeight 的 M3 观感），仅把活动段换成渐变着色。
class GradientSliderTrackShape extends RoundedRectSliderTrackShape {
  const GradientSliderTrackShape({this.colors = defaultColors});

  static const defaultColors = [
    Color(0xFF7C5CFC),
    Color(0xFFB388FF),
    Color(0xFFF06292),
  ];

  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackHeight = sliderTheme.trackHeight;
    if (trackHeight == null || trackHeight <= 0) return;

    final isLTR = textDirection == TextDirection.ltr;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
    );
    final trackRadius = Radius.circular(trackRect.height / 2);
    final activeTrackRadius = Radius.circular(
      (trackRect.height + additionalActiveTrackHeight) / 2,
    );

    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? const Color(0x2A000000);
    // 渐变以整条轨道为坐标系：活动段相当于从全渐变中揭示左侧部分
    final activePaint = Paint()
      ..shader = LinearGradient(
        colors: isLTR ? colors : colors.reversed.toList(),
      ).createShader(trackRect);

    final bool drawInactiveTrack =
        thumbCenter.dx < (trackRect.right - (trackHeight / 2));
    if (drawInactiveTrack) {
      context.canvas.drawRRect(
        RRect.fromLTRBR(
          thumbCenter.dx - (trackHeight / 2),
          isLTR
              ? trackRect.top
              : trackRect.top - (additionalActiveTrackHeight / 2),
          trackRect.right,
          isLTR
              ? trackRect.bottom
              : trackRect.bottom + (additionalActiveTrackHeight / 2),
          isLTR ? trackRadius : activeTrackRadius,
        ),
        inactivePaint,
      );
    }
    final bool drawActiveTrack =
        thumbCenter.dx > (trackRect.left + (trackHeight / 2));
    if (drawActiveTrack) {
      context.canvas.drawRRect(
        RRect.fromLTRBR(
          trackRect.left,
          isLTR
              ? trackRect.top - (additionalActiveTrackHeight / 2)
              : trackRect.top,
          thumbCenter.dx + (trackHeight / 2),
          isLTR
              ? trackRect.bottom + (additionalActiveTrackHeight / 2)
              : trackRect.bottom,
          isLTR ? activeTrackRadius : trackRadius,
        ),
        activePaint,
      );
    }
  }
}
