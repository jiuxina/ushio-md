// ============================================================================
// 莫奈取色工具类
//
// 实现从图片提取主色并生成 Material You 配色方案
// 基于 material_color_utilities 库
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../models/monet_config.dart';

/// 莫奈取色工具类
///
/// 提供从图片提取颜色并生成完整配色方案的功能
class MonetPalette {
  /// 从图片文件提取源色
  ///
  /// [imagePath] 图片文件路径
  /// [maxColors] 最多提取的颜色数量
  ///
  /// 返回提取的颜色列表（按重要性排序）
  static Future<List<Color>> extractColorsFromImage(
    String imagePath, {
    int maxColors = 5,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found: $imagePath');
    }

    final bytes = await file.readAsBytes();
    return extractColorsFromBytes(bytes, maxColors: maxColors);
  }

  /// 从字节数据提取源色
  ///
  /// [bytes] 图片字节数据
  /// [maxColors] 最多提取的颜色数量
  static Future<List<Color>> extractColorsFromBytes(
    Uint8List bytes, {
    int maxColors = 5,
  }) async {
    // 解码图片
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    // 转换为 RGBA 字节数据
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to get image byte data');
    }

    final rgbaBytes = byteData.buffer.asUint8List();
    
    // 将 RGBA 转换为 ARGB 整数数组
    final pixels = <int>[];
    for (int i = 0; i < rgbaBytes.length; i += 4) {
      final r = rgbaBytes[i];
      final g = rgbaBytes[i + 1];
      final b = rgbaBytes[i + 2];
      final a = rgbaBytes[i + 3];
      // ARGB 格式: 0xAARRGGBB
      final argb = (a << 24) | (r << 16) | (g << 8) | b;
      pixels.add(argb);
    }

    // 使用 QuantizerCelebi 量化颜色
    final quantizerResult = await QuantizerCelebi().quantize(pixels, maxColors);
    
    // 使用 Score 评分获取最适合的颜色
    final rankedColors = Score.score(quantizerResult.colorToCount, desired: maxColors);

    // 转换为 Flutter Color 列表
    final colors = <Color>[];
    for (final argb in rankedColors) {
      colors.add(Color(argb));
    }

    // 清理资源
    image.dispose();

    return colors;
  }

  /// 从源色生成配色方案
  ///
  /// [sourceColor] 源色（种子色）
  /// [variant] 配色风格变体
  /// [contrastLevel] 对比度调整 (-1.0 到 1.0)
  static MonetScheme generateScheme(
    Color sourceColor, {
    MonetStyleVariant variant = MonetStyleVariant.tonalSpot,
    double contrastLevel = 0.0,
  }) {
    final sourceArgb = sourceColor.toARGB32();

    // 根据变体选择对应的 DynamicScheme
    final DynamicScheme lightScheme = _createDynamicScheme(
      sourceArgb: sourceArgb,
      variant: variant,
      isDark: false,
      contrastLevel: contrastLevel,
    );

    final DynamicScheme darkScheme = _createDynamicScheme(
      sourceArgb: sourceArgb,
      variant: variant,
      isDark: true,
      contrastLevel: contrastLevel,
    );

    // 转换为 MonetColorScheme
    return MonetScheme(
      lightScheme: _convertToMonetColorScheme(lightScheme),
      darkScheme: _convertToMonetColorScheme(darkScheme),
      sourceColor: sourceColor,
      styleVariant: variant,
    );
  }

  /// 创建 DynamicScheme
  static DynamicScheme _createDynamicScheme({
    required int sourceArgb,
    required MonetStyleVariant variant,
    required bool isDark,
    required double contrastLevel,
  }) {
    final sourceColorHct = Hct.fromInt(sourceArgb);

    switch (variant) {
      case MonetStyleVariant.tonalSpot:
        return SchemeTonalSpot(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.neutral:
        return SchemeNeutral(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.vibrant:
        return SchemeVibrant(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.monochrome:
        return SchemeMonochrome(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.fidelity:
        return SchemeFidelity(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.fruitSalad:
        return SchemeFruitSalad(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.expressive:
        return SchemeExpressive(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
      case MonetStyleVariant.rainbow:
        return SchemeRainbow(
          sourceColorHct: sourceColorHct,
          isDark: isDark,
          contrastLevel: contrastLevel,
        );
    }
  }

  /// 将 DynamicScheme 转换为 MonetColorScheme
  static MonetColorScheme _convertToMonetColorScheme(DynamicScheme scheme) {
    return MonetColorScheme(
      primary: Color(MaterialDynamicColors.primary.getArgb(scheme)),
      primaryContainer: Color(MaterialDynamicColors.primaryContainer.getArgb(scheme)),
      onPrimary: Color(MaterialDynamicColors.onPrimary.getArgb(scheme)),
      onPrimaryContainer: Color(MaterialDynamicColors.onPrimaryContainer.getArgb(scheme)),
      secondary: Color(MaterialDynamicColors.secondary.getArgb(scheme)),
      secondaryContainer: Color(MaterialDynamicColors.secondaryContainer.getArgb(scheme)),
      onSecondary: Color(MaterialDynamicColors.onSecondary.getArgb(scheme)),
      onSecondaryContainer: Color(MaterialDynamicColors.onSecondaryContainer.getArgb(scheme)),
      tertiary: Color(MaterialDynamicColors.tertiary.getArgb(scheme)),
      tertiaryContainer: Color(MaterialDynamicColors.tertiaryContainer.getArgb(scheme)),
      onTertiary: Color(MaterialDynamicColors.onTertiary.getArgb(scheme)),
      onTertiaryContainer: Color(MaterialDynamicColors.onTertiaryContainer.getArgb(scheme)),
      error: Color(MaterialDynamicColors.error.getArgb(scheme)),
      errorContainer: Color(MaterialDynamicColors.errorContainer.getArgb(scheme)),
      onError: Color(MaterialDynamicColors.onError.getArgb(scheme)),
      onErrorContainer: Color(MaterialDynamicColors.onErrorContainer.getArgb(scheme)),
      background: Color(MaterialDynamicColors.background.getArgb(scheme)),
      onBackground: Color(MaterialDynamicColors.onBackground.getArgb(scheme)),
      surface: Color(MaterialDynamicColors.surface.getArgb(scheme)),
      surfaceVariant: Color(MaterialDynamicColors.surfaceVariant.getArgb(scheme)),
      onSurface: Color(MaterialDynamicColors.onSurface.getArgb(scheme)),
      onSurfaceVariant: Color(MaterialDynamicColors.onSurfaceVariant.getArgb(scheme)),
      outline: Color(MaterialDynamicColors.outline.getArgb(scheme)),
      outlineVariant: Color(MaterialDynamicColors.outlineVariant.getArgb(scheme)),
      shadow: Color(MaterialDynamicColors.shadow.getArgb(scheme)),
      inverseSurface: Color(MaterialDynamicColors.inverseSurface.getArgb(scheme)),
      onInverseSurface: Color(MaterialDynamicColors.inverseOnSurface.getArgb(scheme)),
      inversePrimary: Color(MaterialDynamicColors.inversePrimary.getArgb(scheme)),
      surfaceTint: Color(MaterialDynamicColors.surfaceTint.getArgb(scheme)),
    );
  }

  /// 从图片生成完整配置
  ///
  /// [imagePath] 图片路径
  /// [name] 配置名称
  /// [variant] 配色风格
  /// [contrastLevel] 对比度调整
  static Future<MonetConfig> generateFromImage({
    required String imagePath,
    required String name,
    MonetStyleVariant variant = MonetStyleVariant.tonalSpot,
    double contrastLevel = 0.0,
  }) async {
    // 提取颜色
    final colors = await extractColorsFromImage(imagePath);
    if (colors.isEmpty) {
      throw Exception('No colors extracted from image');
    }

    // 使用第一个颜色作为源色
    final sourceColor = colors.first;

    // 生成配色方案
    final scheme = generateScheme(
      sourceColor,
      variant: variant,
      contrastLevel: contrastLevel,
    );

    // 创建配置
    return MonetConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      sourceImagePath: imagePath,
      sourceColor: sourceColor,
      styleVariant: variant,
      contrastLevel: contrastLevel,
      scheme: scheme,
    );
  }

  /// 从颜色生成配置
  ///
  /// [sourceColor] 源色
  /// [name] 配置名称
  /// [variant] 配色风格
  /// [contrastLevel] 对比度调整
  static MonetConfig generateFromColor({
    required Color sourceColor,
    required String name,
    MonetStyleVariant variant = MonetStyleVariant.tonalSpot,
    double contrastLevel = 0.0,
  }) {
    final scheme = generateScheme(
      sourceColor,
      variant: variant,
      contrastLevel: contrastLevel,
    );

    return MonetConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      sourceColor: sourceColor,
      styleVariant: variant,
      contrastLevel: contrastLevel,
      scheme: scheme,
    );
  }

  /// 重新生成配色方案
  ///
  /// 根据 [config] 中的参数重新生成配色方案
  static MonetConfig regenerateScheme(MonetConfig config) {
    final scheme = generateScheme(
      config.sourceColor,
      variant: config.styleVariant,
      contrastLevel: config.contrastLevel,
    );

    return config.copyWith(scheme: scheme);
  }

  /// 获取配色预览列表
  ///
  /// 返回主要颜色的预览列表，用于UI展示
  static List<Color> getPreviewColors(MonetColorScheme scheme) {
    return [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
  }

  /// 获取调色板颜色
  ///
  /// 返回更完整的颜色列表，用于详细预览
  static List<(String, Color)> getPaletteColors(MonetColorScheme scheme) {
    return [
      ('Primary', scheme.primary),
      ('Primary Container', scheme.primaryContainer),
      ('Secondary', scheme.secondary),
      ('Secondary Container', scheme.secondaryContainer),
      ('Tertiary', scheme.tertiary),
      ('Tertiary Container', scheme.tertiaryContainer),
      ('Surface', scheme.surface),
      ('Surface Variant', scheme.surfaceVariant),
      ('Background', scheme.background),
      ('Error', scheme.error),
      ('Outline', scheme.outline),
    ];
  }
}

/// 配色风格变体工具扩展
extension MonetStyleVariantUtils on MonetStyleVariant {
  /// 所有可用的变体
  static List<MonetStyleVariant> get allVariants => [
        MonetStyleVariant.tonalSpot,
        MonetStyleVariant.neutral,
        MonetStyleVariant.vibrant,
        MonetStyleVariant.monochrome,
        MonetStyleVariant.fidelity,
        MonetStyleVariant.fruitSalad,
        MonetStyleVariant.expressive,
        MonetStyleVariant.rainbow,
      ];
}
