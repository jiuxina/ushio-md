import 'package:flutter/material.dart';
import '../utils/app_style.dart';
import 'liquid_glass_card.dart';
import 'outer_shadow.dart';

/// 统一的表面容器组件，根据当前 UI 风格自动应用相应效果。
///
/// - 经典描边 / 简洁立体：[AppStyleTheme.surfaceDecoration] 只画填充和描边，
///   阴影交给 [OuterShadow]，避免半透明填充把自己的阴影透出来变成内阴影
/// - 液态玻璃：[LiquidGlassCard] 提供磨砂模糊 + 折射，不再叠加填充与阴影
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

    Widget wrapMargin(Widget body) =>
        margin == null ? body : Padding(padding: margin!, child: body);

    if (appStyle.useLiquidGlass) {
      return wrapMargin(
        SizedBox(
          width: width,
          height: height,
          child: LiquidGlassCard(
            borderRadius: borderRadius,
            child: Container(
              padding: padding,
              alignment: alignment,
              child: child,
            ),
          ),
        ),
      );
    }

    return wrapMargin(
      OuterShadow(
        shadows: appStyle.outerShadow(prominent: prominent),
        borderRadius: borderRadius,
        child: Container(
          width: width,
          height: height,
          padding: padding,
          alignment: alignment,
          decoration: appStyle.surfaceDecoration(
            borderRadius: borderRadius,
            color: color,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
