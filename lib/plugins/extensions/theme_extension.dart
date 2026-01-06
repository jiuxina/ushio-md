// ============================================================================
// 主题扩展点
// 
// 允许插件添加自定义主题配色方案
// ============================================================================

import 'package:flutter/material.dart';

/// 插件主题扩展
/// 
/// 定义插件添加的主题配色
class PluginThemeExtension {
  /// 主题唯一标识
  final String themeId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 主题名称
  final String themeName;
  
  /// 浅色模式配色
  final ThemeColors? lightColors;
  
  /// 深色模式配色
  final ThemeColors? darkColors;

  PluginThemeExtension({
    required this.themeId,
    required this.pluginId,
    required this.themeName,
    this.lightColors,
    this.darkColors,
  });

  /// 从 JSON 解析
  factory PluginThemeExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginThemeExtension(
      themeId: json['id'] as String? ?? pluginId,
      pluginId: pluginId,
      themeName: json['name'] as String? ?? 'Unknown Theme',
      lightColors: json['light'] != null 
          ? ThemeColors.fromJson(json['light'] as Map<String, dynamic>)
          : null,
      darkColors: json['dark'] != null
          ? ThemeColors.fromJson(json['dark'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 主题颜色配置
class ThemeColors {
  final Color? primary;
  final Color? secondary;
  final Color? surface;
  final Color? background;
  final Color? error;
  final Color? onPrimary;
  final Color? onSecondary;
  final Color? onSurface;
  final Color? onBackground;
  final Color? onError;

  ThemeColors({
    this.primary,
    this.secondary,
    this.surface,
    this.background,
    this.error,
    this.onPrimary,
    this.onSecondary,
    this.onSurface,
    this.onBackground,
    this.onError,
  });

  /// 从 JSON 解析
  factory ThemeColors.fromJson(Map<String, dynamic> json) {
    return ThemeColors(
      primary: _parseColor(json['primary']),
      secondary: _parseColor(json['secondary']),
      surface: _parseColor(json['surface']),
      background: _parseColor(json['background']),
      error: _parseColor(json['error']),
      onPrimary: _parseColor(json['onPrimary']),
      onSecondary: _parseColor(json['onSecondary']),
      onSurface: _parseColor(json['onSurface']),
      onBackground: _parseColor(json['onBackground']),
      onError: _parseColor(json['onError']),
    );
  }

  /// 解析颜色字符串
  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // 支持 #RRGGBB 或 #AARRGGBB 格式
      String hex = value.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    return null;
  }

  /// 应用到 ColorScheme
  ColorScheme applyTo(ColorScheme base) {
    return base.copyWith(
      primary: primary ?? base.primary,
      secondary: secondary ?? base.secondary,
      surface: surface ?? base.surface,
      error: error ?? base.error,
      onPrimary: onPrimary ?? base.onPrimary,
      onSecondary: onSecondary ?? base.onSecondary,
      onSurface: onSurface ?? base.onSurface,
      onError: onError ?? base.onError,
    );
  }
}
