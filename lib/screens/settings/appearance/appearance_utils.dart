// ============================================================================
// 外观设置工具方法
//
// 提供颜色选择器、滑块等共用 UI 组件
// ============================================================================

import 'package:flutter/material.dart';

/// 外观设置工具类，包含共用的 UI 组件
class AppearanceUtils {
  AppearanceUtils._();

  /// 解析十六进制颜色字符串
  static Color? parseHexColor(String hex) {
    try {
      String cleanHex = hex.trim().toUpperCase();
      if (cleanHex.startsWith('#')) {
        cleanHex = cleanHex.substring(1);
      }
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex'; // 添加完全不透明
      }
      if (cleanHex.length == 8) {
        final intValue = int.parse(cleanHex, radix: 16);
        return Color(intValue);
      }
    } catch (_) {}
    return null;
  }

  /// 构建 HSL 滑块
  static List<Widget> buildHslSliders(Color color, void Function(Color) onUpdate) {
    final hsl = HSLColor.fromColor(color);
    
    return [
      // 色相滑块
      Row(
        children: [
          SizedBox(width: 40, child: Text('H: ${(hsl.hue).round()}°')),
          Expanded(
            child: Slider(
              value: hsl.hue,
              min: 0,
              max: 360,
              onChanged: (value) {
                onUpdate(HSLColor.fromAHSL(1.0, value, hsl.saturation, hsl.lightness).toColor());
              },
            ),
          ),
        ],
      ),
      // 饱和度滑块
      Row(
        children: [
          SizedBox(width: 40, child: Text('S: ${(hsl.saturation * 100).round()}%')),
          Expanded(
            child: Slider(
              value: hsl.saturation,
              min: 0,
              max: 1,
              onChanged: (value) {
                onUpdate(HSLColor.fromAHSL(1.0, hsl.hue, value, hsl.lightness).toColor());
              },
            ),
          ),
        ],
      ),
      // 亮度滑块
      Row(
        children: [
          SizedBox(width: 40, child: Text('L: ${(hsl.lightness * 100).round()}%')),
          Expanded(
            child: Slider(
              value: hsl.lightness,
              min: 0,
              max: 1,
              onChanged: (value) {
                onUpdate(HSLColor.fromAHSL(1.0, hsl.hue, hsl.saturation, value).toColor());
              },
            ),
          ),
        ],
      ),
    ];
  }

  /// 构建 RGB 滑块
  static List<Widget> buildRgbSliders(Color color, void Function(Color) onUpdate) {
    return [
      // R 滑块
      Row(
        children: [
          SizedBox(width: 40, child: Text('R: ${color.red}')),
          Expanded(
            child: Slider(
              value: color.red.toDouble(),
              min: 0,
              max: 255,
              onChanged: (value) {
                onUpdate(Color.fromARGB(255, value.round(), color.green, color.blue));
              },
            ),
          ),
        ],
      ),
      // G 滑块
      Row(
        children: [
          SizedBox(width: 40, child: Text('G: ${color.green}')),
          Expanded(
            child: Slider(
              value: color.green.toDouble(),
              min: 0,
              max: 255,
              onChanged: (value) {
                onUpdate(Color.fromARGB(255, color.red, value.round(), color.blue));
              },
            ),
          ),
        ],
      ),
      // B 滑块
      Row(
        children: [
          SizedBox(width: 40, child: Text('B: ${color.blue}')),
          Expanded(
            child: Slider(
              value: color.blue.toDouble(),
              min: 0,
              max: 255,
              onChanged: (value) {
                onUpdate(Color.fromARGB(255, color.red, color.green, value.round()));
              },
            ),
          ),
        ],
      ),
    ];
  }

  /// 显示颜色选择器弹窗
  static void showColorPicker({
    required BuildContext context,
    required Color initialColor,
    required void Function(Color) onColorSelected,
    String? title,
    List<Color>? presetColors,
    bool showPreview = false,
    String? previewText,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        Color selectedColor = initialColor;
        bool useHslMode = true;
        final hexController = TextEditingController(
          text: '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
        );
        
        return StatefulBuilder(
          builder: (context, setState) {
            final newHex = '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
            if (hexController.text.toUpperCase() != newHex) {
              hexController.text = newHex;
            }
            
            return AlertDialog(
              title: Text(title ?? '选择颜色'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 颜色预览（可选）
                    if (showPreview) ...[
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            previewText ?? '预览文字',
                            style: TextStyle(
                              color: selectedColor.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 预设颜色网格
                    if (presetColors != null && presetColors.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: presetColors.map((color) {
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 20,
                                      color: color.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 十六进制输入
                    Row(
                      children: [
                        Text('HEX', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: InputDecoration(
                              hintText: '#RRGGBB',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (value) {
                              final color = parseHexColor(value);
                              if (color != null) {
                                setState(() {
                                  selectedColor = color;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 模式切换
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => useHslMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: useHslMode
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              child: Text(
                                'HSL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: useHslMode
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => useHslMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !useHslMode
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              child: Text(
                                'RGB',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !useHslMode
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 颜色滑块
                    if (useHslMode)
                      ...buildHslSliders(selectedColor, (color) {
                        setState(() {
                          selectedColor = color;
                        });
                      })
                    else
                      ...buildRgbSliders(selectedColor, (color) {
                        setState(() {
                          selectedColor = color;
                        });
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    onColorSelected(selectedColor);
                    Navigator.of(context).pop();
                  },
                  child: const Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示数字编辑弹窗
  static void showNumberEditDialog({
    required BuildContext context,
    required double initialValue,
    required double min,
    required double max,
    required void Function(double) onChanged,
    String? title,
    String? suffix,
    int decimalPlaces = 0,
    String? invalidRangeMessage,
  }) {
    final controller = TextEditingController(
      text: decimalPlaces > 0
          ? initialValue.toStringAsFixed(decimalPlaces)
          : initialValue.round().toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title ?? '编辑数值'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(
              decimal: decimalPlaces > 0,
            ),
            decoration: InputDecoration(
              suffixText: suffix,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null && parsed >= min && parsed <= max) {
                onChanged(parsed);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(invalidRangeMessage ?? '请输入 $min 到 $max 之间的数值'),
                  ),
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text);
                if (parsed != null && parsed >= min && parsed <= max) {
                  onChanged(parsed);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(invalidRangeMessage ?? '请输入 $min 到 $max 之间的数值'),
                    ),
                  );
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }
}
