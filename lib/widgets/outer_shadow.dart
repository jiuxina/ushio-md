import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 只落在容器外侧的阴影。
///
/// [BoxDecoration.boxShadow] 把阴影画在填充之下，半透明卡片会让自己的阴影
/// 从填充里透出来，边缘内侧出现一圈暗带，看起来就是内阴影。这里先把阴影
/// 合成到独立图层，再用同一条圆角路径把容器自身区域擦除，阴影只剩外侧。
class OuterShadow extends StatelessWidget {
  const OuterShadow({
    super.key,
    required this.shadows,
    required this.borderRadius,
    this.child,
  });

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (shadows.isEmpty) return child ?? const SizedBox.shrink();
    return CustomPaint(
      painter: _OuterShadowPainter(
        shadows: shadows,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({
    required this.shadows,
    required this.borderRadius,
  });

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final base = borderRadius.toRRect(rect);

    var reach = 0.0;
    for (final shadow in shadows) {
      reach = math.max(
        reach,
        shadow.blurRadius + shadow.offset.distance + shadow.spreadRadius.abs(),
      );
    }

    canvas.saveLayer(rect.inflate(reach), Paint());
    final paint = Paint()..style = PaintingStyle.fill;
    for (final shadow in shadows) {
      if (shadow.color.a == 0) continue;
      paint
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(shadow.blurStyle, shadow.blurSigma);
      canvas.drawRRect(
        base.shift(shadow.offset).inflate(shadow.spreadRadius),
        paint,
      );
    }
    canvas.drawRRect(base, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) {
    if (oldDelegate.borderRadius != borderRadius) return true;
    if (oldDelegate.shadows.length != shadows.length) return true;
    for (var i = 0; i < shadows.length; i++) {
      if (oldDelegate.shadows[i] != shadows[i]) return true;
    }
    return false;
  }
}
