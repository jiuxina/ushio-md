// ============================================================================
// 背景设置页面（第三层）
//
// 包含：背景图片、编辑器背景、粒子特效
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_background.dart';
import 'appearance_settings_mixin.dart';

class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({super.key});

  @override
  State<BackgroundSettingsScreen> createState() => _BackgroundSettingsScreenState();
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
          title: Text(l10n.backgroundSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            initBrightnessValues(settings);
            initParticleSpeedValue(settings);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 背景
                buildSection(l10n.background, Icons.image, [
                  buildBackgroundSettings(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 编辑器背景
                buildSection(l10n.editorBackground, Icons.wallpaper, [
                  buildEditorBackgroundSettings(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 粒子特效
                buildSection(l10n.particleEffect, Icons.auto_awesome, [
                  buildParticleSettings(settings, l10n),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
