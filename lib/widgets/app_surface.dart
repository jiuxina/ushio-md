import 'package:flutter/material.dart';
import '../utils/app_style.dart';
import 'liquid_glass_card.dart';

/// 统一的表面容器组件，根据当前 UI 风格自动应用相应效果。
///
/// - 经典描边 / 简洁立体：使用 [AppStyleTheme.surfaceDecoration] 的 Container
/// - 液态玻璃：使用 [LiquidGlassCard] 包裹（磨砂模糊 + 蒙版），同时保留阴影
///
/// 所有使用 `appStyle.surfaceDecoration()` 的地方都应替换为本组件，
/// 确保三种 UI 风格的应用范围完全一致。
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? color;
  final bool prominent;
  final Border? border;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const AppSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
    this.prominent = false,
    this.border,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final isLiquidGlass = appStyle.useLiquidGlass;

    // 非液态玻璃模式：直接使用 Container + surfaceDecoration
    if (!isLiquidGlass) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        alignment: alignment,
        decoration: appStyle.surfaceDecoration(
          borderRadius: borderRadius,
          color: color,
          prominent: prominent,
          border: border,
        ),
        child: child,
      );
    }

    // 液态玻璃模式：LiquidGlassCard 提供磨砂模糊 + 蒙版
    // surfaceDecoration 提供阴影
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: LiquidGlassCard(
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          alignment: alignment,
          decoration: appStyle.surfaceDecoration(
            borderRadius: borderRadius,
            color: Colors.transparent, // 透明，让磨砂效果显示
            prominent: prominent,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
