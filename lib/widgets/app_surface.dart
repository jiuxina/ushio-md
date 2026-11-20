import 'package:flutter/material.dart';
import '../utils/app_style.dart';
import 'liquid_glass_card.dart';
import 'outer_shadow.dart';
import 'readable_surface_scope.dart';

/// 统一的表面容器组件，根据当前 UI 风格自动应用相应效果。
///
/// - 经典描边 / 简洁立体：[AppStyleTheme.surfaceDecoration] 只画填充和描边，
///   阴影交给 [OuterShadow]，避免半透明填充把自己的阴影透出来变成内阴影
/// - 液态玻璃：[LiquidGlassCard] 提供折射，内容衬底在折射之上只绘制一次
///
/// 所有使用 `appStyle.surfaceDecoration()` 的地方都应替换为本组件，
/// 确保三种 UI 风格的应用范围完全一致。
class AppSurface extends StatelessWidget {
  final Widget? child;
  final WidgetBuilder? builder;
  final SurfaceRole role;
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
    this.role = SurfaceRole.card,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
    this.prominent = false,
    this.border,
    this.width,
    this.height,
    this.alignment,
  }) : builder = null;

  /// Build explicit theme/color reads inside the resolved content palette.
  const AppSurface.builder({
    super.key,
    required WidgetBuilder this.builder,
    this.role = SurfaceRole.card,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
    this.prominent = false,
    this.border,
    this.width,
    this.height,
    this.alignment,
  }) : child = null;

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final inheritedPalette = ReadableSurfaceScope.maybeOf(context);
    final palette = role == SurfaceRole.inset && inheritedPalette != null
        ? inheritedPalette.forInset()
        : appStyle.resolveSurface(Theme.of(context), role: role, color: color);

    final content = ReadableSurfaceScope(
      palette: palette,
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Container(
          padding: padding,
          alignment: alignment,
          child: builder?.call(context) ?? child,
        ),
      ),
    );

    Widget wrapMargin(Widget body) =>
        margin == null ? body : Padding(padding: margin!, child: body);

    if (appStyle.useLiquidGlass && role != SurfaceRole.inset) {
      return wrapMargin(
        SizedBox(
          width: width,
          height: height,
          child: LiquidGlassCard(
            borderRadius: borderRadius,
            palette: palette,
            child: content,
          ),
        ),
      );
    }

    return wrapMargin(
      OuterShadow(
        shadows: role == SurfaceRole.inset
            ? const []
            : appStyle.outerShadow(prominent: prominent),
        borderRadius: borderRadius,
        child: Container(
          width: width,
          height: height,
          decoration: appStyle.surfaceDecoration(
            borderRadius: borderRadius,
            color: palette.surface,
            border: border,
          ),
          child: content,
        ),
      ),
    );
  }
}
