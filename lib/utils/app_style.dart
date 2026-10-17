import 'dart:ui';

import 'package:flutter/material.dart';

/// 应用按钮风格模式。
enum AppButtonStyleMode { classic, softShadow, liquidGlass }

/// 统一管理按钮与边框风格的主题扩展。
class AppStyleTheme extends ThemeExtension<AppStyleTheme> {
  final AppButtonStyleMode buttonStyleMode;
  final Color outlineColor;
  final Color mutedSurface;
  final Color strongSurface;
  final Color cardSurface;
  final List<BoxShadow> surfaceShadow;
  final List<BoxShadow> prominentShadow;

  /// 页面背景渐变：由所选纸色方案派生，全站唯一来源。
  final LinearGradient backgroundGradient;
  final double cardOpacity;
  final Color? customCardColor;
  final Color iconColor;
  final Color mutedIconColor;

  const AppStyleTheme({
    required this.buttonStyleMode,
    required this.outlineColor,
    required this.mutedSurface,
    required this.strongSurface,
    required this.cardSurface,
    required this.surfaceShadow,
    required this.prominentShadow,
    required this.backgroundGradient,
    required this.cardOpacity,
    required this.iconColor,
    required this.mutedIconColor,
    this.customCardColor,
  });

  bool get useBorderlessButtons =>
      buttonStyleMode != AppButtonStyleMode.classic;

  bool get useLiquidGlass => buttonStyleMode == AppButtonStyleMode.liquidGlass;

  static AppStyleTheme resolve({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color backgroundColor,
    required Color textSecondary,
    required AppButtonStyleMode buttonStyleMode,
    required double cardOpacity,
    Color? customCardColor,
    Color? customIconColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final isLiquidGlass = buttonStyleMode == AppButtonStyleMode.liquidGlass;
    final effectiveOpacity = isLiquidGlass
        ? (cardOpacity * (isDark ? 0.78 : 0.82)).clamp(0.18, 1.0)
        : cardOpacity;
    final mutedAlpha = (effectiveOpacity * (isDark ? 0.78 : 0.72)).clamp(
      0.0,
      1.0,
    );
    final strongAlpha = (effectiveOpacity * (isDark ? 0.90 : 0.88)).clamp(
      0.0,
      1.0,
    );
    final outlineColor = textSecondary.withValues(
      alpha: buttonStyleMode == AppButtonStyleMode.classic
          ? (isDark ? 0.28 : 0.16)
          : (isDark ? 0.0 : 0.04),
    );
    final shadowColor = Colors.black.withValues(
      alpha: isLiquidGlass ? (isDark ? 0.18 : 0.08) : (isDark ? 0.24 : 0.10),
    );
    // 突出层阴影也用黑色：主色发光的阴影会让卡片看起来自己在亮。
    // 黑色比彩色更含蓄，因此 blur/spread 相应放大，保持原有层级差。
    final prominentShadowColor = Colors.black.withValues(
      alpha: isLiquidGlass ? (isDark ? 0.20 : 0.10) : (isDark ? 0.26 : 0.14),
    );

    // 自定义色非空即覆盖主题默认，无需额外开关
    final effectiveCardSurface = (customCardColor ?? colorScheme.surface)
        .withValues(alpha: effectiveOpacity);
    final baseSurface = customCardColor ?? colorScheme.surface;
    final effectiveIconColor = customIconColor ?? colorScheme.onSurface;
    final effectiveMutedIconColor = customIconColor != null
        ? customIconColor.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant;

    // 页面底色跟随所选纸色方案，只做一档极浅的明度过渡：
    // 浅色端下沉约 6%，深色端下沉约 22%（绝对值仅 ~5/255），避免可辨色带。
    final backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        backgroundColor,
        Color.lerp(
          backgroundColor,
          isDark ? Colors.black : colorScheme.onSurface,
          isDark ? 0.22 : 0.06,
        )!,
      ],
    );

    return AppStyleTheme(
      buttonStyleMode: buttonStyleMode,
      outlineColor: outlineColor,
      mutedSurface: baseSurface.withValues(alpha: mutedAlpha),
      strongSurface: baseSurface.withValues(alpha: strongAlpha),
      cardSurface: effectiveCardSurface,
      surfaceShadow: buttonStyleMode == AppButtonStyleMode.classic
          ? const []
          : [
              BoxShadow(
                color: shadowColor,
                blurRadius: isDark ? 20 : 24,
                offset: const Offset(0, 10),
                spreadRadius: isDark ? -12 : -14,
              ),
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: isLiquidGlass
                      ? (isDark ? 0.04 : 0.55)
                      : (isDark ? 0.02 : 0.7),
                ),
                blurRadius: 12,
                offset: const Offset(0, -1),
                spreadRadius: -10,
              ),
            ],
      cardOpacity: cardOpacity,
      backgroundGradient: backgroundGradient,
      prominentShadow: [
        BoxShadow(
          color: prominentShadowColor,
          blurRadius: buttonStyleMode == AppButtonStyleMode.classic
              ? (isDark ? 18 : 22)
              : (isDark ? 24 : 28),
          offset: const Offset(0, 10),
          spreadRadius: buttonStyleMode == AppButtonStyleMode.classic
              ? -8
              : -12,
        ),
      ],
      customCardColor: customCardColor,
      iconColor: effectiveIconColor,
      mutedIconColor: effectiveMutedIconColor,
    );
  }

  Border? surfaceBorder({Color? color}) {
    if (useBorderlessButtons) return null;
    return Border.all(color: color ?? outlineColor);
  }

  Color optionBackground(BuildContext context, {required bool selected}) {
    if (selected) {
      return Theme.of(context).colorScheme.primary.withValues(
        alpha: useBorderlessButtons ? 0.12 : 0.10,
      );
    }
    return useBorderlessButtons ? strongSurface : Colors.transparent;
  }

  Color cardSurfaceColor(ColorScheme colorScheme) {
    return cardSurface;
  }

  /// 为局部 surface 颜色提供统一的透明度缩放：
  /// 传入的 [alpha] 会与全局卡片透明度相乘，确保"卡片透明度"全局生效。
  /// 如果启用自定义卡片颜色，则使用自定义颜色作为基础色。
  Color scaledSurfaceColor(ColorScheme colorScheme, {double alpha = 1}) {
    final effectiveAlpha = (cardOpacity * alpha).clamp(0.0, 1.0);
    return (customCardColor ?? colorScheme.surface).withValues(
      alpha: effectiveAlpha,
    );
  }

  BoxDecoration surfaceDecoration({
    required BorderRadius borderRadius,
    Color? color,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? cardSurface,
      borderRadius: borderRadius,
      border: border ?? surfaceBorder(),
    );
  }

  /// 卡片阴影必须用 [OuterShadow] 绘制，不要塞进 [surfaceDecoration] 的 boxShadow：
  /// 卡片填充是半透明的，BoxShadow 会从填充下面透出来，在边缘内侧形成内阴影。
  List<BoxShadow> outerShadow({bool prominent = false}) {
    return prominent ? prominentShadow : surfaceShadow;
  }

  @override
  AppStyleTheme copyWith({
    AppButtonStyleMode? buttonStyleMode,
    Color? outlineColor,
    Color? mutedSurface,
    Color? strongSurface,
    Color? cardSurface,
    List<BoxShadow>? surfaceShadow,
    List<BoxShadow>? prominentShadow,
    LinearGradient? backgroundGradient,
    double? cardOpacity,
    Color? customCardColor,
    Color? iconColor,
    Color? mutedIconColor,
  }) {
    return AppStyleTheme(
      buttonStyleMode: buttonStyleMode ?? this.buttonStyleMode,
      outlineColor: outlineColor ?? this.outlineColor,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      strongSurface: strongSurface ?? this.strongSurface,
      cardSurface: cardSurface ?? this.cardSurface,
      surfaceShadow: surfaceShadow ?? this.surfaceShadow,
      prominentShadow: prominentShadow ?? this.prominentShadow,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      customCardColor: customCardColor ?? this.customCardColor,
      iconColor: iconColor ?? this.iconColor,
      mutedIconColor: mutedIconColor ?? this.mutedIconColor,
    );
  }

  @override
  AppStyleTheme lerp(ThemeExtension<AppStyleTheme>? other, double t) {
    if (other is! AppStyleTheme) return this;
    return AppStyleTheme(
      buttonStyleMode: t < 0.5 ? buttonStyleMode : other.buttonStyleMode,
      outlineColor:
          Color.lerp(outlineColor, other.outlineColor, t) ?? outlineColor,
      mutedSurface:
          Color.lerp(mutedSurface, other.mutedSurface, t) ?? mutedSurface,
      strongSurface:
          Color.lerp(strongSurface, other.strongSurface, t) ?? strongSurface,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t) ?? cardSurface,
      surfaceShadow: t < 0.5 ? surfaceShadow : other.surfaceShadow,
      prominentShadow: t < 0.5 ? prominentShadow : other.prominentShadow,
      backgroundGradient: t < 0.5
          ? backgroundGradient
          : other.backgroundGradient,
      cardOpacity: lerpDouble(cardOpacity, other.cardOpacity, t) ?? cardOpacity,
      customCardColor: Color.lerp(customCardColor, other.customCardColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t) ?? iconColor,
      mutedIconColor:
          Color.lerp(mutedIconColor, other.mutedIconColor, t) ?? mutedIconColor,
    );
  }
}

/// 全局图标颜色快捷访问。
///
/// 未设置自定义图标颜色时返回主题默认前景色，否则返回用户选择的颜色。
extension AppIconColorX on BuildContext {
  Color get appIconColor =>
      Theme.of(this).extension<AppStyleTheme>()?.iconColor ??
      Theme.of(this).colorScheme.onSurface;

  Color get appMutedIconColor =>
      Theme.of(this).extension<AppStyleTheme>()?.mutedIconColor ??
      Theme.of(this).colorScheme.onSurfaceVariant;
}
