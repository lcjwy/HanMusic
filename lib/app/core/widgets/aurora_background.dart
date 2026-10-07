import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 流彩极光背景：多个柔和色斑沿慢速轨道漂移。
///
/// 用「径向渐变淡出至透明」模拟弥散光斑，避免 BackdropFilter /
/// ImageFiltered 的实时模糊合成开销；位移经 Transform 在绘制层
/// 完成，不触发布局，可安全常驻于列表页与播放页。
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.strength = 1.0});

  /// 色斑透明度倍率：播放页 1.0，列表页 0.5 左右更克制。
  final double strength;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
        ..repeat();

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 暗色下色斑更透亮才能从深底上浮；亮色下压低避免干扰前景文字
    final baseAlpha = isDark ? 0.26 : 0.14;
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _phase,
          builder: (context, _) {
            final t = _phase.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                for (final blob in _blobs)
                  _BlobView(
                    blob: blob,
                    t: t,
                    alpha: math.min(
                      1.0,
                      baseAlpha * blob.alphaScale * widget.strength,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Blob {
  const _Blob({
    required this.color,
    required this.sizeFactor,
    required this.center,
    required this.orbitX,
    required this.orbitY,
    required this.speed,
    required this.phase,
    this.alphaScale = 1.0,
  });

  final Color color;

  /// 直径相对视口短边的比例。
  final double sizeFactor;

  /// 轨道中心（相对视口的 Alignment）。
  final Alignment center;

  /// 横/纵摆幅相对视口宽高的比例。
  final double orbitX;
  final double orbitY;

  /// 角速度倍率与初相位：让各色斑步调错开，避免整体同步显得机械。
  final double speed;
  final double phase;
  final double alphaScale;
}

const _blobs = [
  _Blob(
    color: Color(0xFF7C5CFC),
    sizeFactor: 1.0,
    center: Alignment(-0.55, -0.5),
    orbitX: 0.18,
    orbitY: 0.14,
    speed: 1.0,
    phase: 0,
  ),
  _Blob(
    color: Color(0xFFF06292),
    sizeFactor: 0.85,
    center: Alignment(0.6, -0.35),
    orbitX: 0.16,
    orbitY: 0.2,
    speed: 0.8,
    phase: 1.7,
  ),
  _Blob(
    color: Color(0xFF26C6DA),
    sizeFactor: 0.9,
    center: Alignment(0.15, 0.55),
    orbitX: 0.2,
    orbitY: 0.12,
    speed: 0.65,
    phase: 3.4,
  ),
  _Blob(
    color: Color(0xFFFFB74D),
    sizeFactor: 0.55,
    center: Alignment(-0.35, 0.6),
    orbitX: 0.12,
    orbitY: 0.16,
    speed: 0.9,
    phase: 5.1,
    alphaScale: 0.7,
  ),
];

class _BlobView extends StatelessWidget {
  const _BlobView({required this.blob, required this.t, required this.alpha});

  final _Blob blob;
  final double t;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortSide = math.min(size.width, size.height);
    final dx =
        math.cos(t * blob.speed + blob.phase) * blob.orbitX * size.width;
    final dy =
        math.sin(t * blob.speed + blob.phase) * blob.orbitY * size.height;
    final diameter = blob.sizeFactor * shortSide;
    return Align(
      alignment: blob.center,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                blob.color.withValues(alpha: alpha),
                blob.color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
