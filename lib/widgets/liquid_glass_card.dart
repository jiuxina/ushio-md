import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/app_style.dart';

/// 液态玻璃卡片组件。
///
/// 使用 BackdropFilter 高斯模糊 + 半透明蒙版实现磨砂玻璃效果。
/// 不使用 shader，保持简洁和稳定。
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 非液态玻璃模式：直接返回子组件
    if (!appStyle.useLiquidGlass) {
      return child;
    }

    final radius = borderRadius ?? BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            // 磨砂玻璃蒙版：半透明白色/深色
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.15),
            // 微妙的内边框增强玻璃感
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
