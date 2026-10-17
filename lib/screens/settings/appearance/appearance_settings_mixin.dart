// ============================================================================
// 外观设置 Mixin
//
// 包含所有外观设置页面的共用方法
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/app_style.dart';
import '../../../utils/constants.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/settings_section.dart';
import '../../../services/font_service.dart';
import '../../../utils/image_accent.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/liquid_glass_card.dart';
import '../../../widgets/outer_shadow.dart';

/// 外观设置共用方法 Mixin
mixin AppearanceSettingsMixin<T extends StatefulWidget> on State<T> {
  // 防抖定时器
  Timer? _backgroundBrightnessDebounce;
  Timer? _editorBackgroundBrightnessDebounce;

  // 待定值
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
  double get pendingBackgroundBrightness => _pendingBackgroundBrightness;
  double get pendingEditorBackgroundBrightness =>
      _pendingEditorBackgroundBrightness;

  AppStyleTheme get appStyle => Theme.of(context).extension<AppStyleTheme>()!;

  void initAppearanceMixin() {
    _homeTitleController = TextEditingController();
    _loadCustomFonts();
  }

  void disposeAppearanceMixin() {
    _homeTitleController.dispose();
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

  /// 更新待定亮度值
  void updatePendingBackgroundBrightness(double value) {
    _pendingBackgroundBrightness = value;
  }

  void updatePendingEditorBackgroundBrightness(double value) {
    _pendingEditorBackgroundBrightness = value;
  }

  /// 构建设置区块
  Widget buildSection(String title, IconData icon, List<Widget> children) {
    return SettingsSection(title: title, icon: icon, children: children);
  }

  /// 构建选项装饰
  ///
  /// 只画填充和描边；阴影必须配 [buildOptionOuterShadow] 交给 OuterShadow，
  /// 否则半透明填充会把阴影透出来变成内阴影。
  static const BorderRadius optionRadius = BorderRadius.all(
    Radius.circular(12),
  );

  BoxDecoration buildOptionDecoration({required bool isSelected}) {
    final primary = Theme.of(context).colorScheme.primary;
    return appStyle.surfaceDecoration(
      borderRadius: optionRadius,
      color: appStyle.optionBackground(context, selected: isSelected),
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: isSelected ? primary : appStyle.outlineColor,
              width: isSelected ? 2 : 1,
            ),
    );
  }

  List<BoxShadow> buildOptionOuterShadow({required bool isSelected}) {
    return appStyle.outerShadow(
      prominent: isSelected && appStyle.useBorderlessButtons,
    );
  }

  /// 选项卡片：填充与描边来自 [buildOptionDecoration]，阴影由 OuterShadow 画在外侧
  Widget optionCard({
    required bool isSelected,
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return OuterShadow(
      shadows: buildOptionOuterShadow(isSelected: isSelected),
      borderRadius: optionRadius,
      child: Container(
        padding: padding,
        decoration: buildOptionDecoration(isSelected: isSelected),
        child: child,
      ),
    );
  }

  /// 图标选择卡片：AnimatedContainer 只做填充/描边动画，阴影由 OuterShadow 画在外侧
  Widget borderedOptionCard({
    required bool isSelected,
    required EdgeInsetsGeometry padding,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    required Widget child,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: margin,
      child: OuterShadow(
        shadows: appStyle.useBorderlessButtons
            ? appStyle.surfaceShadow
            : const [],
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: padding,
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 0.1)
                : (appStyle.useBorderlessButtons
                      ? appStyle.strongSurface
                      : Colors.transparent),
            borderRadius: radius,
            border: appStyle.useBorderlessButtons
                ? null
                : Border.all(
                    color: isSelected
                        ? primary
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// 构建主题模式选择器
  Widget buildThemeModeSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
      child: optionCard(
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : context.appIconColor,
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
  Widget buildLanguageSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
      child: optionCard(
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : context.appIconColor,
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

  /// 构建 UI 风格选择器
  Widget buildButtonStyleSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final options =
        <({AppButtonStyleMode mode, IconData icon, String title, String desc})>[
          (
            mode: AppButtonStyleMode.classic,
            icon: Icons.crop_square_rounded,
            title: l10n.uiStyleClassic,
            desc: l10n.uiStyleClassicDesc,
          ),
          (
            mode: AppButtonStyleMode.softShadow,
            icon: Icons.auto_awesome_rounded,
            title: l10n.uiStyleSoftShadow,
            desc: l10n.uiStyleSoftShadowDesc,
          ),
          (
            mode: AppButtonStyleMode.liquidGlass,
            icon: Icons.water_drop_outlined,
            title: l10n.uiStyleLiquidGlass,
            desc: l10n.uiStyleLiquidGlassDesc,
          ),
        ];

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _buildStyleTile(settings, options[i])),
            ],
          ],
        ),
        if (settings.buttonStyleMode == AppButtonStyleMode.liquidGlass &&
            settings.cardOpacity < 0.55)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.uiStyleOpacityHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStyleTile(
    SettingsProvider settings,
    ({AppButtonStyleMode mode, IconData icon, String title, String desc})
    option,
  ) {
    final isSelected = settings.buttonStyleMode == option.mode;
    final primary = Theme.of(context).colorScheme.primary;
    final surface = option.mode == AppButtonStyleMode.liquidGlass
        ? appStyle.cardSurfaceColor(Theme.of(context).colorScheme)
        : (option.mode == AppButtonStyleMode.softShadow &&
                  appStyle.useBorderlessButtons
              ? appStyle.strongSurface
              : Theme.of(context).colorScheme.surface);

    return Tooltip(
      message: option.desc,
      child: GestureDetector(
        onTap: () => settings.setButtonStyleMode(option.mode),
        child: optionCard(
          isSelected: isSelected,
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    option.icon,
                    size: 18,
                    color: isSelected ? primary : context.appIconColor,
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check_circle, size: 16, color: primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                option.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? primary : null,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 22,
                child: _buildStylePreview(option.mode, surface, primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStylePreview(
    AppButtonStyleMode mode,
    Color surface,
    Color primary,
  ) {
    if (mode == AppButtonStyleMode.liquidGlass) {
      return LiquidGlassCard(
        borderRadius: BorderRadius.circular(8),
        child: AppSurface(
          borderRadius: BorderRadius.circular(8),
          color: surface,
          child: const SizedBox.expand(),
        ),
      );
    }
    return Container(
      width: double.infinity,
      decoration: mode == AppButtonStyleMode.softShadow
          ? BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
            )
          : BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary),
            ),
    );
  }

  /// 构建百分比透明度滑块
  Widget buildOpacitySlider({
    required String label,
    required double value,
    required double min,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final percent = '${(value * 100).round()}%';
    return Row(
      children: [
        Text(label),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: 1.0,
            divisions: divisions,
            label: percent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(percent, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  /// 构建主题配色方案选择器
  Widget buildThemeSchemeSelector({
    required List<ThemeScheme> schemes,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: List.generate(schemes.length, (index) {
        final scheme = schemes[index];
        final isSelected = selectedIndex == index;
        return GestureDetector(
          onTap: () => onSelect(index),
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
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 字体选择行：下拉框占满剩余宽度并省略号截断，
  /// 否则长字体名在窄屏上会撑破 Row。
  Widget _buildFontRow({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(12),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
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
          DropdownMenuItem(
            value: font.fontFamily,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 长字体名（如思源黑体 + 下载图标）在窄屏上会撑破下拉框，
                // 这里必须可收缩并截断，否则 RenderFlex overflow。
                Flexible(
                  child: Text(font.name, overflow: TextOverflow.ellipsis),
                ),
                if (font.needDownload) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.cloud_download,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ],
            ),
          ),
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

    // 处理字体选择变更
    Future<void> handleFontChange(
      String? fontFamily,
      Future<void> Function(String) setter,
    ) async {
      if (fontFamily == null) return;

      // 检查是否是需要下载的内置字体
      final fontOption = AppConstants.availableFonts.firstWhere(
        (f) => f.fontFamily == fontFamily,
        orElse: () => const FontOption(name: '', fontFamily: ''),
      );

      if (fontOption.needDownload) {
        // 检查是否已下载
        final isDownloaded = await FontService.isBuiltinFontDownloaded(
          fontFamily,
        );

        if (!isDownloaded && mounted) {
          // 显示下载确认对话框
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.downloadFont),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.downloadFontConfirm(fontOption.name)),
                  const SizedBox(height: 8),
                  Text(
                    fontOption.downloadDesc ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.downloadFontNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(l10n.download),
                ),
              ],
            ),
          );

          if (confirmed != true) return;

          // 开始下载
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.downloadingFont(fontOption.name)),
                  ],
                ),
                duration: const Duration(minutes: 5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          final result = await FontService.downloadBuiltinFont(fontFamily);

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();

            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.fontDownloadSuccess(fontOption.name)),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              // 重新加载自定义字体列表
              await _loadCustomFonts();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.fontDownloadFailed(fontOption.name)),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              return;
            }
          }
        }
      }

      await setter(fontFamily);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFontRow(
          label: l10n.uiFont,
          value: getValidFontFamily(settings.uiFontFamily),
          items: fontItems,
          onChanged: (value) =>
              handleFontChange(value, settings.setUiFontFamily),
        ),
        const SizedBox(height: 12),
        _buildFontRow(
          label: l10n.editorFont,
          value: getValidFontFamily(settings.editorFontFamily),
          items: fontItems,
          onChanged: (value) =>
              handleFontChange(value, settings.setEditorFontFamily),
        ),
        const SizedBox(height: 12),
        _buildFontRow(
          label: l10n.customFont,
          value: getValidFontFamily(settings.codeFontFamily),
          items: fontItems,
          onChanged: (value) =>
              handleFontChange(value, settings.setCodeFontFamily),
        ),
        const SizedBox(height: 16),
        // 安装自定义字体按钮
        OutlinedButton.icon(
          onPressed: _loadingFonts
              ? null
              : () async {
                  final fontName = await FontService.installFontFromFile(
                    context,
                  );
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
  Widget buildCodeBlockThemeSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1)
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
                          : context.appIconColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        themeName,
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
          }),
        ),
      ],
    );
  }

  /// 选择背景图片
  Future<void> pickBackgroundImage(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      settings.setBackgroundImage(result.files.single.path);
    }
  }

  /// 从用户选定的图片中提取主色，供「主题色」作为取色来源。
  Future<void> pickAccentFromImage(SettingsProvider settings) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    List<Color> colors;
    try {
      colors = await ImageAccent.fromImageFile(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.accentFromImageFailed)));
      }
      return;
    }
    if (!mounted || colors.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accentFromImage),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in colors)
              GestureDetector(
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  settings.setCustomThemeColor(color);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(dialogContext).colorScheme.outline,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// 选择编辑器背景图片
  Future<void> pickEditorBackgroundImage(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
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
                if (parsed != null &&
                    parsed >= minValue &&
                    parsed <= maxValue) {
                  onSaved(parsed);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${l10n.invalidRange} ($minValue-$maxValue)',
                      ),
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
  Widget buildBackgroundSettings(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.1),
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
  Widget buildEditorBackgroundSettings(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.1),
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
                    settings.updateEditorBackgroundBrightnessInMemory(
                      value / 100,
                    );
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
                      settings.updateEditorBackgroundBrightnessInMemory(
                        value / 100,
                      );
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

  /// 构建应用图标选择器
  Widget buildAppIconSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
                child: borderedOptionCard(
                  isSelected: isSelected,
                  margin: EdgeInsets.only(right: idx == 0 ? 8 : 0),
                  padding: const EdgeInsets.all(12),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
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
  Widget buildHomeIconSelector(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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
      child: borderedOptionCard(
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
      child: borderedOptionCard(
        isSelected: isSelected,
        padding: const EdgeInsets.all(12),
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
  Widget buildHomeTitleTextField(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
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

  Widget buildTabBarStylePreview(
    Color previewPrimary, {
    required double opacity,
  }) {
    if (!appStyle.useLiquidGlass) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: opacity),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: appStyle.surfaceBorder(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavPreviewIcon(
              Icons.home_rounded,
              selected: true,
              primary: previewPrimary,
            ),
            _buildNavPreviewIcon(
              Icons.folder_special_rounded,
              primary: previewPrimary,
            ),
            _buildNavPreviewIcon(
              Icons.history_rounded,
              primary: previewPrimary,
            ),
            _buildNavPreviewIcon(
              Icons.settings_rounded,
              primary: previewPrimary,
            ),
          ],
        ),
      );
    }

    return GlassTabBar.inline(
      tabs: [
        GlassTab(icon: Icon(Icons.home_rounded), semanticLabel: 'Home'),
        GlassTab(
          icon: Icon(Icons.folder_special_rounded),
          semanticLabel: 'My Files',
        ),
        GlassTab(icon: Icon(Icons.history_rounded), semanticLabel: 'History'),
        GlassTab(icon: Icon(Icons.settings_rounded), semanticLabel: 'Settings'),
      ],
      selectedIndex: 0,
      onTabSelected: (_) {},
      // 与真实导航栏（liquid_glass_capsule_tab_bar）一致，否则拖动滑块时预览毫无变化
      settings: LiquidGlassSettings(visibility: opacity),
    );
  }

  Widget _buildNavPreviewIcon(
    IconData icon, {
    bool selected = false,
    required Color primary,
  }) {
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
