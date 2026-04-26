// ============================================================================
// 其他外观设置页面（第三层）
//
// 包含：应用图标、首页头像、首页标题、底部导航栏透明度
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_background.dart';
import 'appearance_settings_mixin.dart';

class OtherAppearanceSettingsScreen extends StatefulWidget {
  const OtherAppearanceSettingsScreen({super.key});

  @override
  State<OtherAppearanceSettingsScreen> createState() =>
      _OtherAppearanceSettingsScreenState();
}

class _OtherAppearanceSettingsScreenState
    extends State<OtherAppearanceSettingsScreen>
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
          title: Text(l10n.otherAppearanceSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 应用图标
                buildSection(l10n.appIcon, Icons.apps, [
                  buildAppIconSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 首页头像
                buildSection(l10n.homeIcon, Icons.account_circle_outlined, [
                  buildHomeIconSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 首页标题
                buildSection(l10n.homeTitle, Icons.title_rounded, [
                  buildHomeTitleTextField(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 底部导航栏透明度
                buildSection(l10n.bottomNavBar, Icons.tab_rounded, [
                  buildTabBarOpacitySlider(settings, l10n),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
