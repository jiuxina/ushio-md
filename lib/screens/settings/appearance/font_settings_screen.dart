// ============================================================================
// 字体设置页面（第三层）
//
// 包含：界面字体、编辑器字体、代码字体、代码块主题
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_background.dart';
import 'appearance_settings_mixin.dart';

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

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.fontSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 字体选择
                buildSection(l10n.font, Icons.font_download, [
                  buildFontSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 代码块主题
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
