// ============================================================================
// 莫奈配色配置模型
//
// 定义莫奈取色的所有配置选项，包括：
// - 配色风格变体 (TonalSpot, Neutral, Vibrant 等)
// - 高级自定义选项 (对比度、色度、色调范围)
// - 完整的配色方案数据
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';

/// 配色风格变体
///
/// Material You 提供的多种配色风格
enum MonetStyleVariant {
  /// 默认风格 - 色调丰富，适合大多数场景
  tonalSpot,
  
  /// 中性风格 - 低饱和度，适合阅读类应用
  neutral,
  
  /// 鲜艳风格 - 高饱和度，适合活力主题
  vibrant,
  
  /// 单色风格 - 黑白灰色调
  monochrome,
  
  /// 忠实风格 - 保持源色特性
  fidelity,
  
  /// 水果沙拉风格 - 多彩活泼
  fruitSalad,
  
  /// 表达风格 - 强调色彩表现
  expressive,
  
  /// 彩虹风格 - 全光谱色彩
  rainbow,
}

/// 莫奈配色方案
///
/// 存储从源色生成的完整配色方案
class MonetColorScheme {
  /// 主色
  final Color primary;
  
  /// 主色容器
  final Color primaryContainer;
  
  /// 主色上的内容色
  final Color onPrimary;
  
  /// 主色容器上的内容色
  final Color onPrimaryContainer;
  
  /// 次色
  final Color secondary;
  
  /// 次色容器
  final Color secondaryContainer;
  
  /// 次色上的内容色
  final Color onSecondary;
  
  /// 次色容器上的内容色
  final Color onSecondaryContainer;
  
  /// 第三色
  final Color tertiary;
  
  /// 第三色容器
  final Color tertiaryContainer;
  
  /// 第三色上的内容色
  final Color onTertiary;
  
  /// 第三色容器上的内容色
  final Color onTertiaryContainer;
  
  /// 错误色
  final Color error;
  
  /// 错误色容器
  final Color errorContainer;
  
  /// 错误色上的内容色
  final Color onError;
  
  /// 错误色容器上的内容色
  final Color onErrorContainer;
  
  /// 背景色
  final Color background;
  
  /// 背景上的内容色
  final Color onBackground;
  
  /// 表面色
  final Color surface;
  
  /// 表面变体
  final Color surfaceVariant;
  
  /// 表面上的内容色
  final Color onSurface;
  
  /// 表面变体上的内容色
  final Color onSurfaceVariant;
  
  /// 轮廓色
  final Color outline;
  
  /// 轮廓变体
  final Color outlineVariant;
  
  /// 阴影色
  final Color shadow;
  
  /// 反转表面色
  final Color inverseSurface;
  
  /// 反转表面上的内容色
  final Color onInverseSurface;
  
  /// 反转主色
  final Color inversePrimary;
  
  /// 表面着色
  final Color surfaceTint;

  const MonetColorScheme({
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondary,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiary,
    required this.onTertiaryContainer,
    required this.error,
    required this.errorContainer,
    required this.onError,
    required this.onErrorContainer,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.shadow,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.surfaceTint,
  });

  /// 转换为 Flutter ColorScheme
  ColorScheme toFlutterColorScheme({required Brightness brightness}) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: shadow,
      inverseSurface: inverseSurface,
      onInverseSurface: onInverseSurface,
      inversePrimary: inversePrimary,
      surfaceTint: surfaceTint,
    );
  }

  /// 从 JSON Map 创建
  factory MonetColorScheme.fromJson(Map<String, dynamic> json) {
    return MonetColorScheme(
      primary: Color(json['primary'] as int),
      primaryContainer: Color(json['primaryContainer'] as int),
      onPrimary: Color(json['onPrimary'] as int),
      onPrimaryContainer: Color(json['onPrimaryContainer'] as int),
      secondary: Color(json['secondary'] as int),
      secondaryContainer: Color(json['secondaryContainer'] as int),
      onSecondary: Color(json['onSecondary'] as int),
      onSecondaryContainer: Color(json['onSecondaryContainer'] as int),
      tertiary: Color(json['tertiary'] as int),
      tertiaryContainer: Color(json['tertiaryContainer'] as int),
      onTertiary: Color(json['onTertiary'] as int),
      onTertiaryContainer: Color(json['onTertiaryContainer'] as int),
      error: Color(json['error'] as int),
      errorContainer: Color(json['errorContainer'] as int),
      onError: Color(json['onError'] as int),
      onErrorContainer: Color(json['onErrorContainer'] as int),
      background: Color(json['background'] as int),
      onBackground: Color(json['onBackground'] as int),
      surface: Color(json['surface'] as int),
      surfaceVariant: Color(json['surfaceVariant'] as int),
      onSurface: Color(json['onSurface'] as int),
      onSurfaceVariant: Color(json['onSurfaceVariant'] as int),
      outline: Color(json['outline'] as int),
      outlineVariant: Color(json['outlineVariant'] as int),
      shadow: Color(json['shadow'] as int),
      inverseSurface: Color(json['inverseSurface'] as int),
      onInverseSurface: Color(json['onInverseSurface'] as int),
      inversePrimary: Color(json['inversePrimary'] as int),
      surfaceTint: Color(json['surfaceTint'] as int),
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'primary': primary.toARGB32(),
      'primaryContainer': primaryContainer.toARGB32(),
      'onPrimary': onPrimary.toARGB32(),
      'onPrimaryContainer': onPrimaryContainer.toARGB32(),
      'secondary': secondary.toARGB32(),
      'secondaryContainer': secondaryContainer.toARGB32(),
      'onSecondary': onSecondary.toARGB32(),
      'onSecondaryContainer': onSecondaryContainer.toARGB32(),
      'tertiary': tertiary.toARGB32(),
      'tertiaryContainer': tertiaryContainer.toARGB32(),
      'onTertiary': onTertiary.toARGB32(),
      'onTertiaryContainer': onTertiaryContainer.toARGB32(),
      'error': error.toARGB32(),
      'errorContainer': errorContainer.toARGB32(),
      'onError': onError.toARGB32(),
      'onErrorContainer': onErrorContainer.toARGB32(),
      'background': background.toARGB32(),
      'onBackground': onBackground.toARGB32(),
      'surface': surface.toARGB32(),
      'surfaceVariant': surfaceVariant.toARGB32(),
      'onSurface': onSurface.toARGB32(),
      'onSurfaceVariant': onSurfaceVariant.toARGB32(),
      'outline': outline.toARGB32(),
      'outlineVariant': outlineVariant.toARGB32(),
      'shadow': shadow.toARGB32(),
      'inverseSurface': inverseSurface.toARGB32(),
      'onInverseSurface': onInverseSurface.toARGB32(),
      'inversePrimary': inversePrimary.toARGB32(),
      'surfaceTint': surfaceTint.toARGB32(),
    };
  }
}

/// 莫奈配色完整方案（包含浅色和深色）
class MonetScheme {
  /// 浅色模式配色
  final MonetColorScheme lightScheme;
  
  /// 深色模式配色
  final MonetColorScheme darkScheme;
  
  /// 源色（用于生成此方案的种子色）
  final Color sourceColor;
  
  /// 配色风格
  final MonetStyleVariant styleVariant;

  const MonetScheme({
    required this.lightScheme,
    required this.darkScheme,
    required this.sourceColor,
    required this.styleVariant,
  });

  /// 从 JSON 创建
  factory MonetScheme.fromJson(Map<String, dynamic> json) {
    return MonetScheme(
      lightScheme: MonetColorScheme.fromJson(json['lightScheme'] as Map<String, dynamic>),
      darkScheme: MonetColorScheme.fromJson(json['darkScheme'] as Map<String, dynamic>),
      sourceColor: Color(json['sourceColor'] as int),
      styleVariant: MonetStyleVariant.values[json['styleVariant'] as int],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'lightScheme': lightScheme.toJson(),
      'darkScheme': darkScheme.toJson(),
      'sourceColor': sourceColor.toARGB32(),
      'styleVariant': styleVariant.index,
    };
  }
}

/// 莫奈配色配置
///
/// 存储完整的莫奈配色设置，可持久化
class MonetConfig {
  /// 唯一标识
  final String id;
  
  /// 配置名称
  final String name;
  
  /// 源图片路径（可选）
  final String? sourceImagePath;
  
  /// 源色
  final Color sourceColor;
  
  /// 配色风格
  final MonetStyleVariant styleVariant;
  
  /// 对比度调整 (-1.0 到 1.0，0.0 为默认)
  final double contrastLevel;
  
  /// 是否启用
  final bool isEnabled;
  
  /// 生成的完整配色方案
  final MonetScheme scheme;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 最后修改时间
  final DateTime updatedAt;

  MonetConfig({
    required this.id,
    required this.name,
    this.sourceImagePath,
    required this.sourceColor,
    required this.styleVariant,
    this.contrastLevel = 0.0,
    this.isEnabled = true,
    required this.scheme,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 复制并修改
  MonetConfig copyWith({
    String? id,
    String? name,
    String? sourceImagePath,
    Color? sourceColor,
    MonetStyleVariant? styleVariant,
    double? contrastLevel,
    bool? isEnabled,
    MonetScheme? scheme,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonetConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      sourceColor: sourceColor ?? this.sourceColor,
      styleVariant: styleVariant ?? this.styleVariant,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      isEnabled: isEnabled ?? this.isEnabled,
      scheme: scheme ?? this.scheme,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 从 JSON 创建
  factory MonetConfig.fromJson(Map<String, dynamic> json) {
    return MonetConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceImagePath: json['sourceImagePath'] as String?,
      sourceColor: Color(json['sourceColor'] as int),
      styleVariant: MonetStyleVariant.values[json['styleVariant'] as int],
      contrastLevel: (json['contrastLevel'] as num?)?.toDouble() ?? 0.0,
      isEnabled: json['isEnabled'] as bool? ?? true,
      scheme: MonetScheme.fromJson(json['scheme'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceImagePath': sourceImagePath,
      'sourceColor': sourceColor.toARGB32(),
      'styleVariant': styleVariant.index,
      'contrastLevel': contrastLevel,
      'isEnabled': isEnabled,
      'scheme': scheme.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 从 JSON 字符串创建
  factory MonetConfig.fromJsonString(String jsonString) {
    return MonetConfig.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  /// 转换为 JSON 字符串
  String toJsonString() {
    return json.encode(toJson());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonetConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 配色风格变体扩展
extension MonetStyleVariantExtension on MonetStyleVariant {
  /// 获取显示名称
  String getDisplayName() {
    switch (this) {
      case MonetStyleVariant.tonalSpot:
        return '色调丰富';
      case MonetStyleVariant.neutral:
        return '中性低饱和';
      case MonetStyleVariant.vibrant:
        return '鲜艳活力';
      case MonetStyleVariant.monochrome:
        return '单色黑白';
      case MonetStyleVariant.fidelity:
        return '忠实原色';
      case MonetStyleVariant.fruitSalad:
        return '水果沙拉';
      case MonetStyleVariant.expressive:
        return '表现力强';
      case MonetStyleVariant.rainbow:
        return '彩虹光谱';
    }
  }

  /// 获取描述
  String getDescription() {
    switch (this) {
      case MonetStyleVariant.tonalSpot:
        return '默认风格，色调丰富，适合大多数场景';
      case MonetStyleVariant.neutral:
        return '低饱和度，适合阅读类应用';
      case MonetStyleVariant.vibrant:
        return '高饱和度，适合活力主题';
      case MonetStyleVariant.monochrome:
        return '黑白灰色调，极简风格';
      case MonetStyleVariant.fidelity:
        return '保持源色特性，忠实还原';
      case MonetStyleVariant.fruitSalad:
        return '多彩活泼，适合轻松场景';
      case MonetStyleVariant.expressive:
        return '强调色彩表现，大胆配色';
      case MonetStyleVariant.rainbow:
        return '全光谱色彩，绚丽多彩';
    }
  }

  /// 获取图标
  IconData getIcon() {
    switch (this) {
      case MonetStyleVariant.tonalSpot:
        return Icons.palette_outlined;
      case MonetStyleVariant.neutral:
        return Icons.invert_colors_off_outlined;
      case MonetStyleVariant.vibrant:
        return Icons.auto_awesome_outlined;
      case MonetStyleVariant.monochrome:
        return Icons.filter_b_and_w_outlined;
      case MonetStyleVariant.fidelity:
        return Icons.color_lens_outlined;
      case MonetStyleVariant.fruitSalad:
        return Icons.local_florist_outlined;
      case MonetStyleVariant.expressive:
        return Icons.brush_outlined;
      case MonetStyleVariant.rainbow:
        return Icons.gradient_outlined;
    }
  }
}
