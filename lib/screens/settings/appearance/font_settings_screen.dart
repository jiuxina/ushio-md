// ============================================================================
// 文字与字体页面（第三层）
//
// 包含：语言、界面/编辑器/代码字体、界面文字颜色、编辑器文字颜色、代码块主题
// ============================================================================

import 'package:flutter/material.dart';
import '../../../utils/capsule_nav_insets.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_background.dart';
import 'appearance_settings_mixin.dart';
import 'color_setting_selector.dart';

class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({super.key});

  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends State<FontSettingsScreen>
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
    final brightness = Theme.of(context).brightness;

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.textAndFontSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + systemNavBottomInset(context),
              ),
              children: [
                buildSection(l10n.language, Icons.language, [
                  buildLanguageSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.font, Icons.font_download, [
                  buildFontSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.uiFontColor, Icons.text_fields, [
                  ColorSettingSelector(
                    presets: SettingsProvider.uiFontColors,
                    selectedPresetIndex: settings.customUiFontColor == null
                        ? settings.uiFontColorIndex
                        : null,
                    customColor: settings.customUiFontColor,
                    customLabel: l10n.customUiFontColor,
                    pickerInitialColor: settings.uiFontColorFor(brightness),
                    showTextPreview: true,
                    onPresetSelected: settings.setUiFontColorIndex,
                    onCustomColorPicked: settings.setCustomUiFontColor,
                  ),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.editorFontColor, Icons.edit_note, [
                  ColorSettingSelector(
                    presets: SettingsProvider.editorFontColors,
                    selectedPresetIndex: settings.customEditorFontColor == null
                        ? settings.editorFontColorIndex
                        : null,
                    customColor: settings.customEditorFontColor,
                    customLabel: l10n.customEditorFontColor,
                    pickerInitialColor: settings.editorFontColorFor(brightness),
                    description: l10n.editorFontColorDesc,
                    showTextPreview: true,
                    onPresetSelected: settings.setEditorFontColorIndex,
                    onCustomColorPicked: settings.setCustomEditorFontColor,
                  ),
                ]),

                const SizedBox(height: 16),

                buildSection(l10n.codeBlockTheme, Icons.code_rounded, [
                  buildCodeBlockThemeSelector(settings, l10n),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
