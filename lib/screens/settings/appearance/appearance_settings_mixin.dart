// ============================================================================
// 外观设置 Mixin
//
// 包含所有外观设置页面的共用方法
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/app_style.dart';
import '../../../utils/constants.dart';
import '../../../services/font_service.dart';
import '../../../l10n/app_localizations.dart';
import 'appearance_utils.dart';

/// 外观设置共用方法 Mixin
mixin AppearanceSettingsMixin<T extends StatefulWidget> on State<T> {
  // 防抖定时器
  Timer? _particleSpeedDebounce;
  Timer? _backgroundBrightnessDebounce;
  Timer? _editorBackgroundBrightnessDebounce;

  // 待定值
  double _pendingParticleSpeed = 0.5;
  double _pendingBackgroundBrightness = 100;
  double _pendingEditorBackgroundBrightness = 100;

  // 自定义字体列表
  List<CustomFontInfo> _customFonts = [];
  bool _loadingFonts = true;
  late final TextEditingController _homeTitleController;

  // Getters
  List<CustomFontInfo> get customFonts => _customFonts;
  bool get loadingFonts => _loadingFonts;
  TextEditingController get homeTitleController => _homeTitleController;
  double get pendingParticleSpeed => _pendingParticleSpeed;
  double get pendingBackgroundBrightness => _pendingBackgroundBrightness;
  double get pendingEditorBackgroundBrightness => _pendingEditorBackgroundBrightness;

  AppStyleTheme get appStyle => Theme.of(context).extension<AppStyleTheme>()!;

  void initAppearanceMixin() {
    _homeTitleController = TextEditingController();
    _loadCustomFonts();
  }

  void disposeAppearanceMixin() {
    _homeTitleController.dispose();
    _particleSpeedDebounce?.cancel();
    _backgroundBrightnessDebounce?.cancel();
    _editorBackgroundBrightnessDebounce?.cancel();
  }

  Future<void> _loadCustomFonts() async {
    final fonts = await FontService.getInstalledCustomFonts();
    if (mounted) {
      setState(() {
        _customFonts = fonts;
        _loadingFonts = false;
      });
    }
  }

  /// 初始化亮度值
  void initBrightnessValues(SettingsProvider settings) {
    if (_pendingBackgroundBrightness == 100 &&
        settings.backgroundBrightness != 1.0) {
      _pendingBackgroundBrightness = settings.backgroundBrightness * 100;
    }
    if (_pendingEditorBackgroundBrightness == 100 &&
        settings.editorBackgroundBrightness != 1.0) {
      _pendingEditorBackgroundBrightness =
          settings.editorBackgroundBrightness * 100;
    }
  }

  /// 初始化粒子速率值
  void initParticleSpeedValue(SettingsProvider settings) {
    if (_pendingParticleSpeed == 0.5 &&
        settings.particleSpeed != 0.5) {
      // 将实际值 0.01-0.5 转换为显示值 0.1-1.0
      _pendingParticleSpeed = settings.particleSpeed * 2;
    }
  }

  /// 更新待定亮度值
  void updatePendingBackgroundBrightness(double value) {
    _pendingBackgroundBrightness = value;
  }

  void updatePendingEditorBackgroundBrightness(double value) {
    _pendingEditorBackgroundBrightness = value;
  }

  void updatePendingParticleSpeed(double value) {
    _pendingParticleSpeed = value;
  }

  /// 构建设置区块
  Widget buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// 构建选项装饰
  BoxDecoration buildOptionDecoration({required bool isSelected}) {
    final primary = Theme.of(context).colorScheme.primary;
    return appStyle.surfaceDecoration(
      borderRadius: BorderRadius.circular(12),
      color: appStyle.optionBackground(context, selected: isSelected),
      prominent: isSelected && appStyle.useBorderlessButtons,
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: isSelected ? primary : appStyle.outlineColor,
              width: isSelected ? 2 : 1,
            ),
    );
  }

  /// 构建主题模式选择器
  Widget buildThemeModeSelector(SettingsProvider settings, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: buildThemeModeOption(
            settings,
            ThemeMode.system,
            Icons.brightness_auto,
            l10n.themeSystem,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: buildThemeModeOption(
            settings,
            ThemeMode.light,
            Icons.light_mode,
            l10n.themeLight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: buildThemeModeOption(
            settings,
            ThemeMode.dark,
            Icons.dark_mode,
            l10n.themeDark,
          ),
        ),
      ],
    );
  }

  Widget buildThemeModeOption(
    SettingsProvider settings,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = settings.themeMode == mode;
    return GestureDetector(
      onTap: () => settings.setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: buildOptionDecoration(isSelected: isSelected),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建语言选择器
  Widget buildLanguageSelector(SettingsProvider settings, AppLocalizations l10n) {
    final currentLocale = settings.locale;
    return Row(
      children: [
        Expanded(
          child: buildLanguageOption(
            settings,
            const Locale('zh'),
            l10n.languageZh,
            currentLocale.languageCode == 'zh',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: buildLanguageOption(
            settings,
            const Locale('en'),
            l10n.languageEn,
            currentLocale.languageCode == 'en',
          ),
        ),
      ],
    );
  }

  Widget buildLanguageOption(
    SettingsProvider settings,
    Locale locale,
    String label,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => settings.setLocale(locale),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: buildOptionDecoration(isSelected: isSelected),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建主题色选择器
  Widget buildThemeColorSelector(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预设主题色
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SettingsProvider.themeColors.asMap().entries.map((entry) {
            final index = entry.key;
            final color = entry.value;
            final isSelected =
                !settings.useCustomThemeColor && settings.primaryColorIndex == index;
            return GestureDetector(
              onTap: () => settings.setPrimaryColorIndex(index),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义主题色
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.customThemeColor),
            Switch(
              value: settings.useCustomThemeColor,
              onChanged: (value) => settings.setUseCustomThemeColor(value),
            ),
          ],
        ),
        if (settings.useCustomThemeColor) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.themeColor),
              const SizedBox(width: 16),
              // 颜色预览和选择按钮
              GestureDetector(
                onTap: () => showThemeColorPicker(settings),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: settings.customThemeColor ??
                        Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (settings.customThemeColor ??
                                Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.colorize,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 显示当前颜色的十六进制值
              if (settings.customThemeColor != null)
                Text(
                  '#${settings.customThemeColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 自适应渐变色开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.adaptiveGradient),
                    const SizedBox(height: 2),
                    Text(
                      l10n.adaptiveGradientDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.adaptiveGradientEnabled,
                onChanged: (value) => settings.setAdaptiveGradientEnabled(value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 显示主题色选择弹窗
  void showThemeColorPicker(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    AppearanceUtils.showColorPicker(
      context: context,
      initialColor:
          settings.customThemeColor ?? Theme.of(context).colorScheme.primary,
      title: l10n.customThemeColor,
      presetColors: SettingsProvider.themeColors,
      showPreview: true,
      previewText: l10n.previewText,
      onColorSelected: (color) => settings.setCustomThemeColor(color),
    );
  }

  /// 构建界面字体颜色选择器
  Widget buildUiFontColorSelector(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预设界面字体颜色
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SettingsProvider.uiFontColors.asMap().entries.map((entry) {
            final index = entry.key;
            final color = entry.value;
            final isSelected =
                !settings.useCustomUiFontColor && settings.uiFontColorIndex == index;
            return GestureDetector(
              onTap: () => settings.setUiFontColorIndex(index),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
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
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义界面字体颜色
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.customUiFontColor),
            Switch(
              value: settings.useCustomUiFontColor,
              onChanged: (value) => settings.setUseCustomUiFontColor(value),
            ),
          ],
        ),
        if (settings.useCustomUiFontColor) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.uiFontColorLabel),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => showUiFontColorPicker(settings),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: settings.customUiFontColor ??
                        Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (settings.customUiFontColor ??
                                Theme.of(context).colorScheme.onSurface)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.colorize,
                    size: 20,
                    color: (settings.customUiFontColor ??
                                Theme.of(context).colorScheme.onSurface)
                            .computeLuminance() >
                            0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (settings.customUiFontColor != null)
                Text(
                  '#${settings.customUiFontColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 自适应渐变色开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.adaptiveGradient),
                    const SizedBox(height: 2),
                    Text(
                      l10n.uiFontAdaptiveGradientDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.uiFontAdaptiveGradientEnabled,
                onChanged: (value) =>
                    settings.setUiFontAdaptiveGradientEnabled(value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 显示界面字体颜色选择弹窗
  void showUiFontColorPicker(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        Color selectedColor =
            settings.customUiFontColor ?? Theme.of(context).colorScheme.onSurface;
        bool useHslMode = true;
        final hexController = TextEditingController(
          text: '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
        );

        return StatefulBuilder(
          builder: (context, setState) {
            final newHex =
                '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
            if (hexController.text.toUpperCase() != newHex) {
              hexController.text = newHex;
            }

            return AlertDialog(
              title: Text(l10n.customUiFontColor),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 颜色预览（白色背景）
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          l10n.previewText,
                          style: TextStyle(
                            color: selectedColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 预设颜色
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          SettingsProvider.uiFontColors.asMap().entries.map((entry) {
                        final color = entry.value;
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
                    // 十六进制输入
                    Row(
                      children: [
                        Text('HEX',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: InputDecoration(
                              hintText: '#RRGGBB',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (value) {
                              final color = AppearanceUtils.parseHexColor(value);
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
                    // HSL/RGB 切换
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
                    // 滑块
                    if (useHslMode)
                      ...AppearanceUtils.buildHslSliders(selectedColor, (color) {
                        setState(() {
                          selectedColor = color;
                        });
                      })
                    else
                      ...AppearanceUtils.buildRgbSliders(selectedColor, (color) {
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
                    settings.setCustomUiFontColor(selectedColor);
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

  /// 构建编辑器文字颜色选择器
  Widget buildEditorFontColorSelector(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 预设编辑器文字颜色
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              SettingsProvider.editorFontColors.asMap().entries.map((entry) {
            final index = entry.key;
            final color = entry.value;
            final isSelected = !settings.useCustomEditorFontColor &&
                settings.editorFontColorIndex == index;
            return GestureDetector(
              onTap: () => settings.setEditorFontColorIndex(index),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
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
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 自定义编辑器文字颜色
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.customEditorFontColor),
            Switch(
              value: settings.useCustomEditorFontColor,
              onChanged: (value) => settings.setUseCustomEditorFontColor(value),
            ),
          ],
        ),
        if (settings.useCustomEditorFontColor) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.editorFontColorLabel),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => showEditorFontColorPicker(settings),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: settings.customEditorFontColor ??
                        Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (settings.customEditorFontColor ??
                                Theme.of(context).colorScheme.onSurface)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.colorize,
                    size: 20,
                    color: (settings.customEditorFontColor ??
                                Theme.of(context).colorScheme.onSurface)
                            .computeLuminance() >
                            0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (settings.customEditorFontColor != null)
                Text(
                  '#${settings.customEditorFontColor!.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 自适应渐变色开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.adaptiveGradient),
                    const SizedBox(height: 2),
                    Text(
                      l10n.editorFontAdaptiveGradientDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.editorFontAdaptiveGradientEnabled,
                onChanged: (value) =>
                    settings.setEditorFontAdaptiveGradientEnabled(value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 显示编辑器文字颜色选择弹窗
  void showEditorFontColorPicker(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        Color selectedColor = settings.customEditorFontColor ??
            Theme.of(context).colorScheme.onSurface;
        bool useHslMode = true;
        final hexController = TextEditingController(
          text: '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
        );

        return StatefulBuilder(
          builder: (context, setState) {
            final newHex =
                '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
            if (hexController.text.toUpperCase() != newHex) {
              hexController.text = newHex;
            }

            return AlertDialog(
              title: Text(l10n.customEditorFontColor),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 颜色预览（白色背景）
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          l10n.previewText,
                          style: TextStyle(
                            color: selectedColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 预设颜色
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SettingsProvider.editorFontColors.asMap().entries
                          .map((entry) {
                        final color = entry.value;
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
                    // 十六进制输入
                    Row(
                      children: [
                        Text('HEX',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            decoration: InputDecoration(
                              hintText: '#RRGGBB',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (value) {
                              final color = AppearanceUtils.parseHexColor(value);
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
                    // HSL/RGB 切换
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
                    // 滑块
                    if (useHslMode)
                      ...AppearanceUtils.buildHslSliders(selectedColor, (color) {
                        setState(() {
                          selectedColor = color;
                        });
                      })
                    else
                      ...AppearanceUtils.buildRgbSliders(selectedColor, (color) {
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
                    settings.setCustomEditorFontColor(selectedColor);
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

  /// 构建按钮样式选择器
  Widget buildButtonStyleSelector(SettingsProvider settings, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: buildButtonStyleOption(
            settings,
            AppButtonStyleMode.classic,
            Icons.crop_square_rounded,
            l10n.buttonStyleClassic,
            l10n.buttonStyleClassicDesc,
            l10n,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildButtonStyleOption(
            settings,
            AppButtonStyleMode.softShadow,
            Icons.auto_awesome_rounded,
            l10n.buttonStyleModern,
            l10n.buttonStyleModernDesc,
            l10n,
          ),
        ),
      ],
    );
  }

  Widget buildButtonStyleOption(
    SettingsProvider settings,
    AppButtonStyleMode mode,
    IconData icon,
    String title,
    String subtitle,
    AppLocalizations l10n,
  ) {
    final isSelected = settings.buttonStyleMode == mode;
    final previewPrimary = Theme.of(context).colorScheme.primary;
    final previewSurface = appStyle.useBorderlessButtons &&
            mode == AppButtonStyleMode.softShadow
        ? appStyle.strongSurface
        : Theme.of(context).colorScheme.surface;

    return GestureDetector(
      onTap: () => settings.setButtonStyleMode(mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: buildOptionDecoration(isSelected: isSelected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? previewPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: previewPrimary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? previewPrimary : null,
                  ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: mode == AppButtonStyleMode.softShadow
                        ? BoxDecoration(
                            color: previewSurface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: appStyle.prominentShadow,
                          )
                        : BoxDecoration(
                            color: previewPrimary,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: previewPrimary),
                          ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.buttonPreview,
                      style: TextStyle(
                        color: mode == AppButtonStyleMode.softShadow
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片透明度滑块
  Widget buildCardOpacitySlider(SettingsProvider settings, AppLocalizations l10n) {
    return Row(
      children: [
        Text(l10n.opacity),
        Expanded(
          child: Slider(
            value: settings.cardOpacity,
            min: 0.4,
            max: 1.0,
            divisions: 12,
            label: '${(settings.cardOpacity * 100).round()}%',
            onChanged: (value) => settings.setCardOpacity(value),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(settings.cardOpacity * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// 构建卡片颜色选择器
  Widget buildCardColorSelector(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 启用自定义颜色开关
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.customCardColor),
            Switch(
              value: settings.useCustomCardColor,
              onChanged: (value) => settings.setUseCustomCardColor(value),
            ),
          ],
        ),
        // 颜色选择器（仅在启用时显示）
        if (settings.useCustomCardColor) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.cardColor),
              const SizedBox(width: 16),
              // 颜色预览和选择按钮
              GestureDetector(
                onTap: () => showCardColorPicker(settings),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: settings.customCardColor ??
                        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (settings.customCardColor ??
                                Theme.of(context).colorScheme.surface)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.colorize,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 重置按钮
              TextButton.icon(
                onPressed: () => settings.setCustomCardColor(null),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.useThemeDefault),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 显示卡片颜色选择弹窗
  void showCardColorPicker(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    final presetColors = [
      Colors.white,
      Colors.black,
      const Color(0xFFF5F5F5),
      const Color(0xFF1E1E1E),
      const Color(0xFFE3F2FD),
      const Color(0xFF0D47A1),
      const Color(0xFFFFF3E0),
      const Color(0xFFE65100),
      const Color(0xFFE8F5E9),
      const Color(0xFF1B5E20),
      const Color(0xFFFCE4EC),
      const Color(0xFF880E4F),
      const Color(0xFFF3E5F5),
      const Color(0xFF4A148C),
    ];

    AppearanceUtils.showColorPicker(
      context: context,
      initialColor: settings.customCardColor ??
          Theme.of(context).colorScheme.surface,
      title: l10n.cardColor,
      presetColors: presetColors,
      onColorSelected: (color) => settings.setCustomCardColor(color),
    );
  }

  /// 构建浅色主题选择器
  Widget buildLightThemeSelector(SettingsProvider settings) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: List.generate(AppConstants.lightThemeSchemes.length, (index) {
        final scheme = AppConstants.lightThemeSchemes[index];
        final isSelected = settings.lightThemeIndex == index;
        return GestureDetector(
          onTap: () => settings.setLightThemeIndex(index),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.background,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  scheme.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.text,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 构建深色主题选择器
  Widget buildDarkThemeSelector(SettingsProvider settings) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: List.generate(AppConstants.darkThemeSchemes.length, (index) {
        final scheme = AppConstants.darkThemeSchemes[index];
        final isSelected = settings.darkThemeIndex == index;
        return GestureDetector(
          onTap: () => settings.setDarkThemeIndex(index),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.background,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  scheme.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.text,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 构建字体选择器
  Widget buildFontSelector(SettingsProvider settings, AppLocalizations l10n) {
    // 构建字体选项列表
    final fontItems = <DropdownMenuItem<String>>[];
    final seenFamilies = <String>{};

    // 1. 添加预设字体
    for (var font in AppConstants.availableFonts) {
      if (seenFamilies.add(font.fontFamily)) {
        fontItems.add(
          DropdownMenuItem(value: font.fontFamily, child: Text(font.name)),
        );
      }
    }

    // 2. 添加自定义字体
    for (final font in _customFonts) {
      // 自定义字体加载时使用的是 font.name 作为 family name
      if (seenFamilies.add(font.name)) {
        fontItems.add(
          DropdownMenuItem(value: font.name, child: Text(font.name)),
        );
      }
    }

    // 确保当前选中的字体在列表中，如果不在（可能被删除），则回退到 System
    String getValidFontFamily(String current) {
      return seenFamilies.contains(current) ? current : 'System';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 界面字体
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.uiFont),
            DropdownButton<String>(
              value: getValidFontFamily(settings.uiFontFamily),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: fontItems,
              onChanged: (value) {
                if (value != null) settings.setUiFontFamily(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 编辑器字体
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.editorFont),
            DropdownButton<String>(
              value: getValidFontFamily(settings.editorFontFamily),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: fontItems,
              onChanged: (value) {
                if (value != null) settings.setEditorFontFamily(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 代码字体
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.customFont),
            DropdownButton<String>(
              value: getValidFontFamily(settings.codeFontFamily),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: fontItems,
              onChanged: (value) {
                if (value != null) settings.setCodeFontFamily(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 安装自定义字体按钮
        OutlinedButton.icon(
          onPressed: _loadingFonts
              ? null
              : () async {
                  final fontName = await FontService.installFontFromFile(context);
                  if (fontName != null) {
                    await _loadCustomFonts();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${l10n.fontInstalled}: "$fontName"'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                },
          icon: const Icon(Icons.add),
          label: Text(l10n.installFont),
        ),
      ],
    );
  }

  /// 构建代码块主题选择器
  Widget buildCodeBlockThemeSelector(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: List.generate(AppConstants.codeBlockThemes.length, (index) {
            final theme = AppConstants.codeBlockThemes[index];
            final isSelected = settings.codeBlockThemeIndex == index;
            // 获取本地化名称
            String themeName;
            switch (theme.name) {
              case 'codeBlockThemeAuto':
                themeName = l10n.codeBlockThemeAuto;
                break;
              case 'codeBlockThemeOneDark':
                themeName = l10n.codeBlockThemeOneDark;
                break;
              case 'codeBlockThemeOneLight':
                themeName = l10n.codeBlockThemeOneLight;
                break;
              case 'codeBlockThemeGithubDark':
                themeName = l10n.codeBlockThemeGithubDark;
                break;
              case 'codeBlockThemeGithubLight':
                themeName = l10n.codeBlockThemeGithubLight;
                break;
              case 'codeBlockThemeNord':
                themeName = l10n.codeBlockThemeNord;
                break;
              case 'codeBlockThemeMaterial':
                themeName = l10n.codeBlockThemeMaterial;
                break;
              default:
                themeName = theme.name;
            }
            return GestureDetector(
              onTap: () => settings.setCodeBlockThemeIndex(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 18,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        themeName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// 选择背景图片
  Future<void> pickBackgroundImage(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      settings.setBackgroundImage(result.files.single.path);
    }
  }

  /// 选择编辑器背景图片
  Future<void> pickEditorBackgroundImage(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      settings.setEditorBackgroundImage(result.files.single.path);
    }
  }

  /// 显示数字编辑弹窗
  void showNumberEditDialog({
    required String title,
    required int currentValue,
    required int minValue,
    required int maxValue,
    required void Function(int) onSaved,
  }) {
    final controller = TextEditingController(text: currentValue.toString());
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: '%',
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed >= minValue && parsed <= maxValue) {
                onSaved(parsed);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${l10n.invalidRange} ($minValue-$maxValue)'),
                  ),
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                if (parsed != null && parsed >= minValue && parsed <= maxValue) {
                  onSaved(parsed);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.invalidRange} ($minValue-$maxValue)'),
                    ),
                  );
                }
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  /// 构建背景设置
  Widget buildBackgroundSettings(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择背景图片
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.background),
            TextButton.icon(
              onPressed: () => pickBackgroundImage(settings),
              icon: const Icon(Icons.image, size: 18),
              label: Text(l10n.selectImage),
            ),
          ],
        ),
        if (settings.backgroundImagePath != null) ...[
          const SizedBox(height: 8),
          // 背景预览
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(settings.backgroundImagePath!),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(l10n.clearImage)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 背景效果选择
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.blurEffect),
              Switch(
                value: settings.backgroundEffect == 'blur',
                onChanged: (value) {
                  settings.setBackgroundEffect(value ? 'blur' : 'none');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.brightness),
              Expanded(
                child: Slider(
                  value: _pendingBackgroundBrightness,
                  min: 0,
                  max: 200,
                  divisions: 200,
                  label: '${_pendingBackgroundBrightness.round()}%',
                  onChanged: (value) {
                    setState(() {
                      _pendingBackgroundBrightness = value;
                    });
                    settings.updateBackgroundBrightnessInMemory(value / 100);
                    _backgroundBrightnessDebounce?.cancel();
                    _backgroundBrightnessDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        settings.setBackgroundBrightness(value / 100);
                      },
                    );
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  showNumberEditDialog(
                    title: l10n.brightness,
                    currentValue: _pendingBackgroundBrightness.round(),
                    minValue: 0,
                    maxValue: 200,
                    onSaved: (value) {
                      setState(() {
                        _pendingBackgroundBrightness = value.toDouble();
                      });
                      settings.updateBackgroundBrightnessInMemory(value / 100);
                      settings.setBackgroundBrightness(value / 100);
                    },
                  );
                },
                child: SizedBox(
                  width: 50,
                  child: Text(
                    '${_pendingBackgroundBrightness.round()}%',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ),
            ],
          ),
          // 模糊强度滑块
          if (settings.backgroundEffect == 'blur') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.blurStrength),
                Expanded(
                  child: Slider(
                    value: settings.backgroundBlur,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: settings.backgroundBlur.round().toString(),
                    onChanged: (value) => settings.setBackgroundBlur(value),
                  ),
                ),
                Text('${settings.backgroundBlur.round()}'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // 移除背景按钮
          TextButton.icon(
            onPressed: () => settings.setBackgroundImage(null),
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            label: Text(
              l10n.clearBackground,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建编辑器背景设置
  Widget buildEditorBackgroundSettings(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.editorBackground),
            TextButton.icon(
              onPressed: () => pickEditorBackgroundImage(settings),
              icon: const Icon(Icons.image, size: 18),
              label: Text(l10n.selectImage),
            ),
          ],
        ),
        if (settings.editorBackgroundImagePath != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(settings.editorBackgroundImagePath!),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(l10n.clearImage)),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.blurEffect),
              Switch(
                value: settings.editorBackgroundBlurEnabled,
                onChanged: (value) {
                  settings.setEditorBackgroundBlurEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.brightness),
              Expanded(
                child: Slider(
                  value: _pendingEditorBackgroundBrightness,
                  min: 0,
                  max: 200,
                  divisions: 200,
                  label: '${_pendingEditorBackgroundBrightness.round()}%',
                  onChanged: (value) {
                    setState(() {
                      _pendingEditorBackgroundBrightness = value;
                    });
                    settings.updateEditorBackgroundBrightnessInMemory(value / 100);
                    _editorBackgroundBrightnessDebounce?.cancel();
                    _editorBackgroundBrightnessDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        settings.setEditorBackgroundBrightness(value / 100);
                      },
                    );
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  showNumberEditDialog(
                    title: l10n.brightness,
                    currentValue: _pendingEditorBackgroundBrightness.round(),
                    minValue: 0,
                    maxValue: 200,
                    onSaved: (value) {
                      setState(() {
                        _pendingEditorBackgroundBrightness = value.toDouble();
                      });
                      settings.updateEditorBackgroundBrightnessInMemory(value / 100);
                      settings.setEditorBackgroundBrightness(value / 100);
                    },
                  );
                },
                child: SizedBox(
                  width: 50,
                  child: Text(
                    '${_pendingEditorBackgroundBrightness.round()}%',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
              ),
            ],
          ),
          if (settings.editorBackgroundBlurEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.blurStrength),
                Expanded(
                  child: Slider(
                    value: settings.editorBackgroundBlur,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: settings.editorBackgroundBlur.round().toString(),
                    onChanged: (value) =>
                        settings.setEditorBackgroundBlur(value),
                  ),
                ),
                Text('${settings.editorBackgroundBlur.round()}'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => settings.setEditorBackgroundImage(null),
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            label: Text(
              l10n.clearBackground,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建粒子效果设置
  Widget buildParticleSettings(SettingsProvider settings, AppLocalizations l10n) {
    const particleTypeIds = ['sakura', 'rain', 'firefly', 'snow'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 启用开关
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.globalParticlesEnabled),
            Switch(
              value: settings.particleEnabled,
              onChanged: (v) => settings.setParticleEnabled(v),
            ),
          ],
        ),
        // 以下选项仅在启用时显示
        if (settings.particleEnabled) ...[
          const SizedBox(height: 16),
          // 效果类型选择器
          Text(
            l10n.particleType,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: particleTypeIds.map((typeId) {
              final isSelected = settings.particleType == typeId;
              String typeName;
              String icon;
              switch (typeId) {
                case 'sakura':
                  typeName = l10n.particleTypeSakura;
                  icon = '🌸';
                  break;
                case 'rain':
                  typeName = l10n.particleTypeRain;
                  icon = '🌧️';
                  break;
                case 'firefly':
                  typeName = l10n.particleTypeFirefly;
                  icon = '✨';
                  break;
                case 'snow':
                  typeName = l10n.particleTypeSnow;
                  icon = '❄️';
                  break;
                default:
                  typeName = typeId;
                  icon = '🌟';
              }
              return GestureDetector(
                onTap: () => settings.setParticleType(typeId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          typeName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // 粒子速率
          // 实际范围: 0.01-0.5，界面显示: 0.1-1.0 (显示值 = 实际值 × 2)
          Builder(
            builder: (context) {
              // 将实际值转换为显示值
              final displayValue = settings.particleSpeed * 2;
              return Row(
                children: [
                  Text(l10n.particleSpeed),
                  Expanded(
                    child: Slider(
                      value: displayValue,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${displayValue.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        // 取消之前的防抖定时器
                        _particleSpeedDebounce?.cancel();
                        // 保存待处理的值
                        _pendingParticleSpeed = value / 2; // 转换为实际值
                        // 设置防抖定时器 (300ms)
                        _particleSpeedDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            settings.setParticleSpeed(_pendingParticleSpeed);
                          },
                        );
                        // 立即更新 UI
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${displayValue.toStringAsFixed(1)}x',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // 高级粒子设置
          Text(
            l10n.advancedParticleSettings,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          // 粒子数量
          Row(
            children: [
              Text(l10n.particleCount),
              Expanded(
                child: Slider(
                  value: settings.particleCount,
                  min: 0.25,
                  max: 2.0,
                  divisions: 7,
                  label: '${settings.particleCount.toStringAsFixed(2)}x',
                  onChanged: (value) => settings.setParticleCount(value),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${settings.particleCount.toStringAsFixed(2)}x',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 粒子大小
          Row(
            children: [
              Text(l10n.particleSize),
              Expanded(
                child: Slider(
                  value: settings.particleSize,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: settings.particleSize.toStringAsFixed(1),
                  onChanged: (value) => settings.setParticleSize(value),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(settings.particleSize.toStringAsFixed(1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 粒子透明度
          Row(
            children: [
              Text(l10n.particleOpacity),
              Expanded(
                child: Slider(
                  value: settings.particleOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: (settings.particleOpacity * 100).round().toString(),
                  onChanged: (value) => settings.setParticleOpacity(value),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('${(settings.particleOpacity * 100).round()}%'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 风向
          Row(
            children: [
              Text(l10n.particleWind),
              Expanded(
                child: Slider(
                  value: settings.particleWind,
                  min: -1.0,
                  max: 1.0,
                  divisions: 20,
                  label: settings.particleWind > 0
                      ? l10n.particleWindRight
                      : settings.particleWind < 0
                          ? l10n.particleWindLeft
                          : l10n.particleWindNone,
                  onChanged: (value) => settings.setParticleWind(value),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建应用图标选择器
  Widget buildAppIconSelector(SettingsProvider settings, AppLocalizations l10n) {
    final options = [
      {'index': 0, 'label': l10n.defaultIcon, 'asset': 'app.png'},
      {'index': 1, 'label': l10n.icon2, 'asset': 'assets/icons/icon2.png'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appIconSelectorHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((opt) {
            final idx = opt['index'] as int;
            final isSelected = settings.appIconIndex == idx;
            return Expanded(
              child: GestureDetector(
                onTap: () => _setAppIcon(settings, idx, l10n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: idx == 0 ? 8 : 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    boxShadow: appStyle.useBorderlessButtons
                        ? appStyle.surfaceShadow
                        : null,
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : (appStyle.useBorderlessButtons
                            ? appStyle.strongSurface
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: appStyle.useBorderlessButtons
                        ? null
                        : Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          opt['asset'] as String,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.image, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          if (isSelected) const SizedBox(width: 4),
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 调用原生频道切换桌面图标
  Future<void> _setAppIcon(
    SettingsProvider settings,
    int iconIndex,
    AppLocalizations l10n,
  ) async {
    if (settings.appIconIndex == iconIndex) return;

    // 仅 Android 支持
    if (!Platform.isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.appIconAndroidOnly),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    const channel = MethodChannel('com.ushiomd/app_icon');
    try {
      await channel.invokeMethod('setAppIcon', {'iconIndex': iconIndex});
      await settings.setAppIconIndex(iconIndex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.appIconChanged),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.appIconChangeFailed}: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// 构建首页头像选择器
  Widget buildHomeIconSelector(SettingsProvider settings, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.homeIconSelectorHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 12),
        // 前三个选项（默认、icon2、隐藏）横排
        Row(
          children: [
            Expanded(
              child: _buildHomeIconOption(
                settings,
                'default',
                l10n.defaultIcon,
                icon: const AssetImage('app.png'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHomeIconOption(
                settings,
                'icon2',
                l10n.icon2,
                icon: const AssetImage('assets/icons/icon2.png'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHomeIconOption(
                settings,
                'none',
                l10n.hidden,
                iconWidget: const Icon(Icons.hide_image_outlined, size: 32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 自定义选项占一行
        _buildHomeIconCustomOption(settings, l10n),
      ],
    );
  }

  Widget _buildHomeIconOption(
    SettingsProvider settings,
    String mode,
    String label, {
    ImageProvider? icon,
    Widget? iconWidget,
  }) {
    final isSelected = settings.homeIconMode == mode;
    return GestureDetector(
      onTap: () => settings.setHomeIconMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          boxShadow: appStyle.useBorderlessButtons
              ? appStyle.surfaceShadow
              : null,
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : (appStyle.useBorderlessButtons
                  ? appStyle.strongSurface
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: appStyle.useBorderlessButtons
              ? null
              : Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 2 : 1,
                ),
        ),
        child: Column(
          children: [
            if (iconWidget != null)
              iconWidget
            else if (icon != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: icon,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image, size: 40),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeIconCustomOption(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final isSelected = settings.homeIconMode == 'custom';
    final customPath = settings.homeIconCustomPath;
    return GestureDetector(
      onTap: () => _pickHomeCustomIcon(settings),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          boxShadow: appStyle.useBorderlessButtons
              ? appStyle.surfaceShadow
              : null,
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : (appStyle.useBorderlessButtons
                  ? appStyle.strongSurface
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: appStyle.useBorderlessButtons
              ? null
              : Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 2 : 1,
                ),
        ),
        child: Row(
          children: [
            if (isSelected && customPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(customPath),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 40),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.customImage,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isSelected && customPath != null
                        ? customPath.split('/').last.split('\\').last
                        : l10n.selectFromGallery,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHomeCustomIcon(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        await settings.setHomeIconCustomPath(path);
        await settings.setHomeIconMode('custom');
      }
    }
  }

  /// 构建首页标题输入框
  Widget buildHomeTitleTextField(SettingsProvider settings, AppLocalizations l10n) {
    final homeTitleText = settings.homeTitleText;
    if (_homeTitleController.text != homeTitleText) {
      _homeTitleController.value = TextEditingValue(
        text: homeTitleText,
        selection: TextSelection.collapsed(offset: homeTitleText.length),
      );
    }
    return TextField(
      controller: _homeTitleController,
      decoration: InputDecoration(
        hintText: l10n.homeTitleHint,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _homeTitleController.clear();
            settings.setHomeTitleText('');
          },
        ),
      ),
      onChanged: (value) => settings.setHomeTitleText(value),
    );
  }

  /// 构建底部导航栏透明度滑块
  Widget buildTabBarOpacitySlider(SettingsProvider settings, AppLocalizations l10n) {
    return Row(
      children: [
        Text(l10n.opacity),
        Expanded(
          child: Slider(
            value: settings.tabBarOpacity,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            label: '${(settings.tabBarOpacity * 100).round()}%',
            onChanged: (value) => settings.setTabBarOpacity(value),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(settings.tabBarOpacity * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
