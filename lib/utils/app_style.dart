import 'dart:ui';

import 'package:flutter/material.dart';

/// 应用按钮风格模式。
enum AppButtonStyleMode {
  classic,
  softShadow,
  liquidGlass,
}

/// 统一管理按钮与边框风格的主题扩展。
class AppStyleTheme extends ThemeExtension<AppStyleTheme> {
  final AppButtonStyleMode buttonStyleMode;
  final Color outlineColor;
  final Color mutedSurface;
  final Color strongSurface;
  final Color cardSurface;
  final List<BoxShadow> surfaceShadow;
  final List<BoxShadow> prominentShadow;
  final double cardOpacity;
  final Color? customCardColor;
  final bool useCustomCardColor;

  const AppStyleTheme({
    required this.buttonStyleMode,
    required this.outlineColor,
    required this.mutedSurface,
    required this.strongSurface,
    required this.cardSurface,
    required this.surfaceShadow,
    required this.prominentShadow,
    required this.cardOpacity,
    this.customCardColor,
    this.useCustomCardColor = false,
  });

  bool get useBorderlessButtons =>
      buttonStyleMode != AppButtonStyleMode.classic;

  bool get useLiquidGlass =>
      buttonStyleMode == AppButtonStyleMode.liquidGlass;

  static AppStyleTheme resolve({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color textSecondary,
    required AppButtonStyleMode buttonStyleMode,
    required double cardOpacity,
    Color? customCardColor,
    bool useCustomCardColor = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final isLiquidGlass = buttonStyleMode == AppButtonStyleMode.liquidGlass;
    final effectiveOpacity = isLiquidGlass
        ? (cardOpacity * (isDark ? 0.78 : 0.82)).clamp(0.18, 1.0)
        : cardOpacity;
    final mutedAlpha = (effectiveOpacity * (isDark ? 0.78 : 0.72))
        .clamp(0.0, 1.0);
    final strongAlpha = (effectiveOpacity * (isDark ? 0.90 : 0.88))
        .clamp(0.0, 1.0);
    final outlineColor = textSecondary.withValues(
      alpha: buttonStyleMode == AppButtonStyleMode.classic
          ? (isDark ? 0.28 : 0.16)
          : (isDark ? 0.0 : 0.04),
    );
    final shadowColor = Colors.black.withValues(
      alpha: isLiquidGlass ? (isDark ? 0.18 : 0.08) : (isDark ? 0.24 : 0.10),
    );
    final prominentColor = colorScheme.primary.withValues(
      alpha: isLiquidGlass ? (isDark ? 0.18 : 0.14) : (isDark ? 0.24 : 0.18),
    );

    // 计算卡片表面颜色：如果启用自定义颜色则使用自定义颜色，否则使用主题默认
    final effectiveCardSurface = useCustomCardColor && customCardColor != null
        ? customCardColor.withValues(alpha: effectiveOpacity)
        : colorScheme.surface.withValues(alpha: effectiveOpacity);

    // 计算muted和strong表面颜色：如果启用自定义颜色则基于自定义颜色
    final baseSurface = useCustomCardColor && customCardColor != null
        ? customCardColor
        : colorScheme.surface;

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
      prominentShadow: [
        BoxShadow(
          color: prominentColor,
          blurRadius: buttonStyleMode == AppButtonStyleMode.classic ? 12 : 20,
          offset: const Offset(0, 8),
          spreadRadius: buttonStyleMode == AppButtonStyleMode.classic ? -8 : -10,
        ),
      ],
      customCardColor: customCardColor,
      useCustomCardColor: useCustomCardColor,
    );
  }

  Border? surfaceBorder({Color? color}) {
    if (useBorderlessButtons) return null;
    return Border.all(color: color ?? outlineColor);
  }

  Color optionBackground(BuildContext context, {required bool selected}) {
    if (selected) {
      return Theme.of(context).colorScheme.primary.withValues(alpha: useBorderlessButtons ? 0.12 : 0.10);
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
    // 如果启用自定义卡片颜色且颜色不为空，使用自定义颜色
    final customColor = customCardColor;
    if (useCustomCardColor && customColor != null) {
      return customColor.withValues(alpha: effectiveAlpha);
    }
    return colorScheme.surface.withValues(alpha: effectiveAlpha);
  }

  BoxDecoration surfaceDecoration({
    required BorderRadius borderRadius,
    Color? color,
    bool prominent = false,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? cardSurface,
      borderRadius: borderRadius,
      border: border ?? surfaceBorder(),
      boxShadow: prominent ? prominentShadow : surfaceShadow,
    );
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
    double? cardOpacity,
    Color? customCardColor,
    bool? useCustomCardColor,
  }) {
    return AppStyleTheme(
      buttonStyleMode: buttonStyleMode ?? this.buttonStyleMode,
      outlineColor: outlineColor ?? this.outlineColor,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      strongSurface: strongSurface ?? this.strongSurface,
      cardSurface: cardSurface ?? this.cardSurface,
      surfaceShadow: surfaceShadow ?? this.surfaceShadow,
      prominentShadow: prominentShadow ?? this.prominentShadow,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      customCardColor: customCardColor ?? this.customCardColor,
      useCustomCardColor: useCustomCardColor ?? this.useCustomCardColor,
    );
  }

  @override
  AppStyleTheme lerp(ThemeExtension<AppStyleTheme>? other, double t) {
    if (other is! AppStyleTheme) return this;
    return AppStyleTheme(
      buttonStyleMode: t < 0.5 ? buttonStyleMode : other.buttonStyleMode,
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t) ?? outlineColor,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t) ?? mutedSurface,
      strongSurface: Color.lerp(strongSurface, other.strongSurface, t) ?? strongSurface,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t) ?? cardSurface,
      surfaceShadow: t < 0.5 ? surfaceShadow : other.surfaceShadow,
      prominentShadow: t < 0.5 ? prominentShadow : other.prominentShadow,
      cardOpacity: lerpDouble(cardOpacity, other.cardOpacity, t) ?? cardOpacity,
      customCardColor: Color.lerp(customCardColor, other.customCardColor, t),
      useCustomCardColor: t < 0.5 ? useCustomCardColor : other.useCustomCardColor,
    );
  }
}
