// ============================================================================
// 表面与背景页面（第三层）
//
// 包含：UI 风格、卡片材质、图标色、底部导航栏、页面背景、编辑器背景、
//       首页头像、首页标题、桌面图标
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import '../../../utils/capsule_nav_insets.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/app_style.dart';
import '../../../utils/constants.dart';
import '../../../widgets/app_background.dart';
import 'appearance_settings_mixin.dart';
import 'color_setting_selector.dart';

class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({super.key});

  @override
  State<BackgroundSettingsScreen> createState() =>
      _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends State<BackgroundSettingsScreen>
    with AppearanceSettingsMixin {
  @override
  void initState() {
    super.initState();
    initAppearanceMixin();
  }

  @override
  void dispose() {
    disposeAppearanceMixin();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.surfaceAndBackgroundSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            initBrightnessValues(settings);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + systemNavBottomInset(context),
              ),
              children: [
                buildSection(l10n.uiStyle, Icons.auto_awesome_rounded, [
                  buildButtonStyleSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.cardAppearance, Icons.style, [
                  buildOpacitySlider(
                    label: l10n.opacity,
                    value: settings.cardOpacity,
                    min: 0.4,
                    divisions: 12,
                    onChanged: settings.setCardOpacity,
                  ),
                  const SizedBox(height: 12),
                  ColorSettingSelector(
                    presets: AppConstants.cardColorPresets,
                    customColor: settings.customCardColor,
                    customLabel: l10n.cardColor,
                    pickerInitialColor: Theme.of(context).colorScheme.surface,
                    clearLabel: l10n.useThemeDefault,
                    onClearCustom: () => settings.setCustomCardColor(null),
                    onPresetSelected: (index) => settings.setCustomCardColor(
                      AppConstants.cardColorPresets[index],
                    ),
                    onCustomColorPicked: settings.setCustomCardColor,
                  ),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.globalIconColor, Icons.format_paint, [
                  ColorSettingSelector(
                    presets: SettingsProvider.globalIconColors,
                    customColor: settings.customIconColor,
                    customLabel: l10n.customGlobalIconColor,
                    pickerInitialColor: context.appIconColor,
                    description: l10n.globalIconColorDesc,
                    clearLabel: l10n.useThemeDefault,
                    onClearCustom: () => settings.setCustomIconColor(null),
                    onPresetSelected: (index) => settings.setCustomIconColor(
                      SettingsProvider.globalIconColors[index],
                    ),
                    onCustomColorPicked: settings.setCustomIconColor,
                  ),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.bottomNavBar, Icons.tab_rounded, [
                  buildTabBarStylePreview(
                    Theme.of(context).colorScheme.primary,
                    opacity: settings.tabBarOpacity,
                  ),
                  const SizedBox(height: 12),
                  buildOpacitySlider(
                    label: l10n.opacity,
                    value: settings.tabBarOpacity,
                    min: 0.1,
                    divisions: 18,
                    onChanged: settings.setTabBarOpacity,
                  ),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.background, Icons.image, [
                  buildBackgroundSettings(settings, l10n),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.editorBackground, Icons.wallpaper, [
                  buildEditorBackgroundSettings(settings, l10n),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.homeIcon, Icons.account_circle_outlined, [
                  buildHomeIconSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.homeTitle, Icons.title_rounded, [
                  buildHomeTitleTextField(settings, l10n),
                ]),

                // 桌面图标切换走 Android MethodChannel，其他平台整块无意义
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 16),
                  buildSection(l10n.appIcon, Icons.apps, [
                    buildAppIconSelector(settings, l10n),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
