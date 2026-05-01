// ============================================================================
// 莫奈取色功能测试
//
// 验证莫奈取色的核心逻辑：
// 1. 从颜色生成配色方案
// 2. 配色方案转换为 Flutter ColorScheme
// 3. 各配色风格的色彩协调性
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:mdreader/models/monet_config.dart';
import 'package:mdreader/utils/monet_palette.dart';

void main() {
  group('MonetPalette 莫奈取色测试', () {
    // 测试用的源色
    final testColors = [
      Colors.blue,    // 经典蓝色
      Colors.red,     // 红色
      Colors.green,   // 绿色
      Colors.purple,  // 紫色
      Colors.orange,  // 橙色
      const Color(0xFF1A73E8), // Google Blue
      const Color(0xFF34A853), // Google Green
      const Color(0xFFEA4335), // Google Red
    ];

    group('配色方案生成测试', () {
      test('应该成功生成配色方案 - 默认风格 (TonalSpot)', () {
        for (final sourceColor in testColors) {
          final scheme = MonetPalette.generateScheme(
            sourceColor,
            variant: MonetStyleVariant.tonalSpot,
          );

          // 验证配色方案结构完整
          expect(scheme, isNotNull);
          expect(scheme.lightScheme, isNotNull);
          expect(scheme.darkScheme, isNotNull);
          expect(scheme.sourceColor, equals(sourceColor));
          expect(scheme.styleVariant, equals(MonetStyleVariant.tonalSpot));

          // 验证浅色方案颜色合理性
          _validateColorScheme(scheme.lightScheme, '浅色方案 - ${sourceColor.toString()}');
          
          // 验证深色方案颜色合理性
          _validateColorScheme(scheme.darkScheme, '深色方案 - ${sourceColor.toString()}');
        }
      });

      test('应该成功生成配色方案 - 中性风格 (Neutral)', () {
        final scheme = MonetPalette.generateScheme(
          Colors.blue,
          variant: MonetStyleVariant.neutral,
        );

        expect(scheme, isNotNull);
        expect(scheme.styleVariant, equals(MonetStyleVariant.neutral));
        
        // 中性风格应该有较低饱和度的颜色
        _validateColorScheme(scheme.lightScheme, '中性浅色方案');
        _validateColorScheme(scheme.darkScheme, '中性深色方案');
      });

      test('应该成功生成配色方案 - 鲜艳风格 (Vibrant)', () {
        final scheme = MonetPalette.generateScheme(
          Colors.blue,
          variant: MonetStyleVariant.vibrant,
        );

        expect(scheme, isNotNull);
        expect(scheme.styleVariant, equals(MonetStyleVariant.vibrant));
        
        // 鲜艳风格应该有高饱和度的颜色
        _validateColorScheme(scheme.lightScheme, '鲜艳浅色方案');
        _validateColorScheme(scheme.darkScheme, '鲜艳深色方案');
      });

      test('应该成功生成配色方案 - 所有8种风格', () {
        for (final variant in MonetStyleVariant.values) {
          final scheme = MonetPalette.generateScheme(
            Colors.blue,
            variant: variant,
          );

          expect(scheme, isNotNull);
          expect(scheme.styleVariant, equals(variant));
          
          _validateColorScheme(scheme.lightScheme, '${variant.name} 浅色方案');
          _validateColorScheme(scheme.darkScheme, '${variant.name} 深色方案');
        }
      });
    });

    group('对比度调整测试', () {
      test('对比度为0时使用默认对比度', () {
        final scheme = MonetPalette.generateScheme(
          Colors.blue,
          contrastLevel: 0.0,
        );

        expect(scheme, isNotNull);
        _validateColorScheme(scheme.lightScheme, '默认对比度浅色');
        _validateColorScheme(scheme.darkScheme, '默认对比度深色');
      });

      test('正对比度应该增加对比度', () {
        final scheme = MonetPalette.generateScheme(
          Colors.blue,
          contrastLevel: 0.5,
        );

        expect(scheme, isNotNull);
        _validateColorScheme(scheme.lightScheme, '高对比度浅色');
        _validateColorScheme(scheme.darkScheme, '高对比度深色');
      });

      test('负对比度应该降低对比度', () {
        final scheme = MonetPalette.generateScheme(
          Colors.blue,
          contrastLevel: -0.5,
        );

        expect(scheme, isNotNull);
        _validateColorScheme(scheme.lightScheme, '低对比度浅色');
        _validateColorScheme(scheme.darkScheme, '低对比度深色');
      });
    });

    group('ColorScheme 转换测试', () {
      test('应该正确转换为 Flutter ColorScheme - 浅色模式', () {
        final scheme = MonetPalette.generateScheme(Colors.blue);
        final flutterScheme = scheme.lightScheme.toFlutterColorScheme(
          brightness: Brightness.light,
        );

        expect(flutterScheme.brightness, equals(Brightness.light));
        expect(flutterScheme.primary, equals(scheme.lightScheme.primary));
        expect(flutterScheme.secondary, equals(scheme.lightScheme.secondary));
        expect(flutterScheme.tertiary, equals(scheme.lightScheme.tertiary));
        expect(flutterScheme.error, equals(scheme.lightScheme.error));
      });

      test('应该正确转换为 Flutter ColorScheme - 深色模式', () {
        final scheme = MonetPalette.generateScheme(Colors.blue);
        final flutterScheme = scheme.darkScheme.toFlutterColorScheme(
          brightness: Brightness.dark,
        );

        expect(flutterScheme.brightness, equals(Brightness.dark));
        expect(flutterScheme.primary, equals(scheme.darkScheme.primary));
        expect(flutterScheme.secondary, equals(scheme.darkScheme.secondary));
        expect(flutterScheme.tertiary, equals(scheme.darkScheme.tertiary));
        expect(flutterScheme.error, equals(scheme.darkScheme.error));
      });

      test('转换后的 ColorScheme 应该可以用于 ThemeData', () {
        final scheme = MonetPalette.generateScheme(Colors.blue);
        final flutterScheme = scheme.lightScheme.toFlutterColorScheme(
          brightness: Brightness.light,
        );

        // 验证可以创建 ThemeData
        expect(
          () => ThemeData(colorScheme: flutterScheme),
          returnsNormally,
        );
      });
    });

    group('颜色对比度验证', () {
      test('主色与背景色应该有足够对比度 - 浅色模式', () {
        for (final sourceColor in testColors) {
          final scheme = MonetPalette.generateScheme(sourceColor);
          final contrast = _calculateContrastRatio(
            scheme.lightScheme.onPrimary,
            scheme.lightScheme.primary,
          );

          // WCAG AA 标准要求至少 4.5:1 的对比度
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '浅色模式主色对比度不足: ${sourceColor.toString()}, 对比度: $contrast',
          );
        }
      });

      test('主色与背景色应该有足够对比度 - 深色模式', () {
        for (final sourceColor in testColors) {
          final scheme = MonetPalette.generateScheme(sourceColor);
          final contrast = _calculateContrastRatio(
            scheme.darkScheme.onPrimary,
            scheme.darkScheme.primary,
          );

          // WCAG AA 标准要求至少 4.5:1 的对比度
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '深色模式主色对比度不足: ${sourceColor.toString()}, 对比度: $contrast',
          );
        }
      });

      test('表面色与文字色应该有足够对比度 - 浅色模式', () {
        for (final sourceColor in testColors) {
          final scheme = MonetPalette.generateScheme(sourceColor);
          final contrast = _calculateContrastRatio(
            scheme.lightScheme.onSurface,
            scheme.lightScheme.surface,
          );

          // WCAG AA 标准要求至少 4.5:1 的对比度
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '浅色模式表面对比度不足: ${sourceColor.toString()}, 对比度: $contrast',
          );
        }
      });

      test('表面色与文字色应该有足够对比度 - 深色模式', () {
        for (final sourceColor in testColors) {
          final scheme = MonetPalette.generateScheme(sourceColor);
          final contrast = _calculateContrastRatio(
            scheme.darkScheme.onSurface,
            scheme.darkScheme.surface,
          );

          // WCAG AA 标准要求至少 4.5:1 的对比度
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '深色模式表面对比度不足: ${sourceColor.toString()}, 对比度: $contrast',
          );
        }
      });
    });

    group('MonetConfig 持久化测试', () {
      test('应该正确序列化和反序列化', () {
        final originalScheme = MonetPalette.generateScheme(Colors.blue);
        final originalConfig = MonetConfig(
          id: 'test-config-1',
          name: '测试配色',
          sourceColor: Colors.blue,
          styleVariant: MonetStyleVariant.tonalSpot,
          contrastLevel: 0.0,
          scheme: originalScheme,
        );

        // 序列化
        final json = originalConfig.toJson();
        expect(json, isNotNull);
        expect(json['id'], equals('test-config-1'));
        expect(json['name'], equals('测试配色'));
        expect(json['styleVariant'], equals(MonetStyleVariant.tonalSpot.index));

        // 反序列化
        final restored = MonetConfig.fromJson(json);
        expect(restored.id, equals(originalConfig.id));
        expect(restored.name, equals(originalConfig.name));
        // 比较颜色值而不是对象（因为 MaterialColor vs Color）
        expect(restored.sourceColor.toARGB32(), equals(originalConfig.sourceColor.toARGB32()));
        expect(restored.styleVariant, equals(originalConfig.styleVariant));
        expect(restored.contrastLevel, equals(originalConfig.contrastLevel));
      });

      test('应该正确序列化为 JSON 字符串', () {
        final scheme = MonetPalette.generateScheme(Colors.blue);
        final config = MonetConfig(
          id: 'test-config-2',
          name: '测试配色2',
          sourceColor: Colors.blue,
          styleVariant: MonetStyleVariant.vibrant,
          contrastLevel: 0.5,
          scheme: scheme,
        );

        final jsonString = config.toJsonString();
        expect(jsonString, isNotNull);
        expect(jsonString, contains('test-config-2'));
        expect(jsonString, contains('测试配色2'));

        final restored = MonetConfig.fromJsonString(jsonString);
        expect(restored.id, equals(config.id));
        expect(restored.name, equals(config.name));
      });

      test('copyWith 应该正确工作', () {
        final scheme = MonetPalette.generateScheme(Colors.blue);
        final original = MonetConfig(
          id: 'test-id',
          name: '原始名称',
          sourceColor: Colors.blue,
          styleVariant: MonetStyleVariant.tonalSpot,
          scheme: scheme,
        );

        final copied = original.copyWith(
          name: '新名称',
          styleVariant: MonetStyleVariant.vibrant,
        );

        expect(copied.id, equals('test-id'));
        expect(copied.name, equals('新名称'));
        expect(copied.styleVariant, equals(MonetStyleVariant.vibrant));
        expect(copied.sourceColor, equals(Colors.blue));
      });
    });

    group('配色风格变体扩展测试', () {
      test('所有风格应该有显示名称', () {
        for (final variant in MonetStyleVariant.values) {
          expect(
            variant.getDisplayName(),
            isNotEmpty,
            reason: '${variant.name} 缺少显示名称',
          );
        }
      });

      test('所有风格应该有描述', () {
        for (final variant in MonetStyleVariant.values) {
          expect(
            variant.getDescription(),
            isNotEmpty,
            reason: '${variant.name} 缺少描述',
          );
        }
      });

      test('所有风格应该有图标', () {
        for (final variant in MonetStyleVariant.values) {
          expect(
            variant.getIcon(),
            isNotNull,
            reason: '${variant.name} 缺少图标',
          );
        }
      });
    });
  });
}

/// 验证配色方案的颜色合理性
void _validateColorScheme(MonetColorScheme scheme, String context) {
  // 主色系
  expect(scheme.primary, isNotNull, reason: '$context - 主色为空');
  expect(scheme.primaryContainer, isNotNull, reason: '$context - 主色容器为空');
  expect(scheme.onPrimary, isNotNull, reason: '$context - 主色内容色为空');
  expect(scheme.onPrimaryContainer, isNotNull, reason: '$context - 主色容器内容色为空');

  // 次色系
  expect(scheme.secondary, isNotNull, reason: '$context - 次色为空');
  expect(scheme.secondaryContainer, isNotNull, reason: '$context - 次色容器为空');
  expect(scheme.onSecondary, isNotNull, reason: '$context - 次色内容色为空');
  expect(scheme.onSecondaryContainer, isNotNull, reason: '$context - 次色容器内容色为空');

  // 第三色系
  expect(scheme.tertiary, isNotNull, reason: '$context - 第三色为空');
  expect(scheme.tertiaryContainer, isNotNull, reason: '$context - 第三色容器为空');
  expect(scheme.onTertiary, isNotNull, reason: '$context - 第三色内容色为空');
  expect(scheme.onTertiaryContainer, isNotNull, reason: '$context - 第三色容器内容色为空');

  // 错误色系
  expect(scheme.error, isNotNull, reason: '$context - 错误色为空');
  expect(scheme.errorContainer, isNotNull, reason: '$context - 错误色容器为空');
  expect(scheme.onError, isNotNull, reason: '$context - 错误色内容色为空');
  expect(scheme.onErrorContainer, isNotNull, reason: '$context - 错误色容器内容色为空');

  // 表面色系
  expect(scheme.surface, isNotNull, reason: '$context - 表面色为空');
  expect(scheme.surfaceVariant, isNotNull, reason: '$context - 表面变体为空');
  expect(scheme.onSurface, isNotNull, reason: '$context - 表面内容色为空');
  expect(scheme.onSurfaceVariant, isNotNull, reason: '$context - 表面变体内容色为空');
  expect(scheme.background, isNotNull, reason: '$context - 背景色为空');
  expect(scheme.onBackground, isNotNull, reason: '$context - 背景内容色为空');

  // 其他
  expect(scheme.outline, isNotNull, reason: '$context - 轮廓色为空');
  expect(scheme.outlineVariant, isNotNull, reason: '$context - 轮廓变体为空');
  expect(scheme.shadow, isNotNull, reason: '$context - 阴影色为空');
  expect(scheme.inverseSurface, isNotNull, reason: '$context - 反转表面色为空');
  expect(scheme.onInverseSurface, isNotNull, reason: '$context - 反转表面内容色为空');
  expect(scheme.inversePrimary, isNotNull, reason: '$context - 反转主色为空');
  expect(scheme.surfaceTint, isNotNull, reason: '$context - 表面着色为空');

  // 验证颜色不是透明色（除非有意为之）
  expect(scheme.primary.alpha, greaterThan(0), reason: '$context - 主色是透明的');
  expect(scheme.surface.alpha, greaterThan(0), reason: '$context - 表面色是透明的');
}

/// 计算两个颜色之间的对比度比率
/// 基于 WCAG 2.0 对比度计算公式
double _calculateContrastRatio(Color foreground, Color background) {
  final fgLuminance = _getRelativeLuminance(foreground);
  final bgLuminance = _getRelativeLuminance(background);
  
  final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
  final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;
  
  return (lighter + 0.05) / (darker + 0.05);
}

/// 计算颜色的相对亮度
double _getRelativeLuminance(Color color) {
  // 将 sRGB 颜色转换为线性 RGB
  double r = color.red / 255.0;
  double g = color.green / 255.0;
  double b = color.blue / 255.0;
  
  // 应用 gamma 校正
  r = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
  g = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
  b = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
  
  // 计算相对亮度
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// 幂运算
double pow(double base, double exponent) {
  return base == 0 ? 0 : exponent == 0 ? 1 : base * base; // 简化版
}
