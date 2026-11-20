// ============================================================================
// 颜色设置选择器
//
// 预设色块 + 末尾「自定义」色块一步直达取色弹窗：
// 点预设即清除自定义，点自定义即生效，不再需要额外的开关。
// ============================================================================

import 'package:flutter/material.dart';

import 'appearance_utils.dart';

class ColorSettingSelector extends StatelessWidget {
  const ColorSettingSelector({
    super.key,
    required this.presets,
    required this.customColor,
    required this.customLabel,
    required this.pickerInitialColor,
    required this.onPresetSelected,
    required this.onCustomColorPicked,
    this.selectedPresetIndex,
    this.description,
    this.showTextPreview = false,
    this.clearLabel,
    this.onClearCustom,
  });

  final List<Color> presets;

  /// 当前生效的自定义颜色；null 表示使用预设
  final Color? customColor;

  /// 「自定义 xxx」文案，同时作为取色弹窗标题
  final String customLabel;

  final Color pickerInitialColor;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<Color> onCustomColorPicked;

  /// 高亮的预设下标；null 表示没有预设处于选中态
  final int? selectedPresetIndex;

  final String? description;

  /// 无预设可退回时（如卡片色、图标色的「跟随主题默认」）提供的清除入口
  final String? clearLabel;
  final VoidCallback? onClearCustom;

  /// 颜色用于文字时，在取色弹窗内用白底展示选中色的文字效果
  final bool showTextPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustom = customColor != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null) ...[
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var index = 0; index < presets.length; index++)
              _buildSwatch(
                context: context,
                color: presets[index],
                selected: !hasCustom && selectedPresetIndex == index,
                onTap: () => onPresetSelected(index),
              ),
            _buildCustomSwatch(context, theme, hasCustom),
          ],
        ),
        if (hasCustom) ...[
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                customLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onClearCustom != null && clearLabel != null)
                TextButton.icon(
                  onPressed: onClearCustom,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(clearLabel!),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSwatch({
    required BuildContext context,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            // 用卡片底色做间隔环，深色卡片上白色环会消失
            color: selected
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: -3,
            ),
          ],
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  Widget _buildCustomSwatch(
    BuildContext context,
    ThemeData theme,
    bool hasCustom,
  ) {
    final color = customColor ?? Colors.transparent;
    return GestureDetector(
      onTap: () => AppearanceUtils.showColorPicker(
        context: context,
        initialColor: hasCustom ? color : pickerInitialColor,
        title: customLabel,
        presetColors: presets,
        showPreview: showTextPreview,
        previewBackgroundColor: showTextPreview ? Colors.white : null,
        onColorSelected: onCustomColorPicked,
      ),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: hasCustom
                ? theme.colorScheme.surface
                : theme.colorScheme.outline.withValues(alpha: 0.6),
            width: hasCustom ? 3 : 1.5,
          ),
          boxShadow: hasCustom
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Icon(
          hasCustom ? Icons.check : Icons.tune,
          color: hasCustom
              ? (color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
              : theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
