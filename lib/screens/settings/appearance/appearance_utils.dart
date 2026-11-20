// ============================================================================
// 外观设置工具方法
//
// 提供颜色选择器、滑块等共用 UI 组件
// ============================================================================

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_modal.dart';

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

  /// 构建 RGB 滑块
  static List<Widget> buildRgbSliders(
    Color color,
    void Function(Color) onUpdate,
  ) {
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
                onUpdate(
                  Color.fromARGB(255, value.round(), color.green, color.blue),
                );
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
                onUpdate(
                  Color.fromARGB(255, color.red, value.round(), color.blue),
                );
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
                onUpdate(
                  Color.fromARGB(255, color.red, color.green, value.round()),
                );
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
    required String title,
    List<Color>? presetColors,
    bool showPreview = false,
    Color? previewBackgroundColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showAppDialog(
      context: context,
      builder: (context) {
        Color selectedColor = initialColor;
        final hexController = TextEditingController(
          text:
              '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
        );

        return StatefulBuilder(
          builder: (context, setState) {
            final newHex =
                '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
            if (hexController.text.toUpperCase() != newHex) {
              hexController.text = newHex;
            }

            return AlertDialog(
              scrollable: true,
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 颜色预览（可选）
                    if (showPreview) ...[
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: previewBackgroundColor ?? selectedColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            l10n.previewText,
                            style: TextStyle(
                              // 预览背景固定时（如白底预览文字色），直接用选中色作为文字色
                              color: previewBackgroundColor != null
                                  ? selectedColor
                                  : selectedColor.computeLuminance() > 0.5
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
                        Text(
                          'HEX',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: InputDecoration(
                              hintText: '#RRGGBB',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
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
                    // 颜色滑块
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
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    onColorSelected(selectedColor);
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
