// ============================================================================
// 外观设置分类页面（第二层）
//
// 展示外观设置的分类列表，点击后跳转到对应的子设置页面（第三层）
// ============================================================================

import 'package:flutter/material.dart';
import '../../utils/capsule_nav_insets.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_background.dart';
import 'appearance/color_theme_screen.dart';
import 'appearance/font_settings_screen.dart';
import 'appearance/background_settings_screen.dart';

class AppearanceCategoriesScreen extends StatelessWidget {
  const AppearanceCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final categories = <({IconData icon, String title, String desc, Widget page})>[
      (
        icon: Icons.palette_outlined,
        title: l10n.colorThemeSettings,
        desc: l10n.colorThemeSettingsDesc,
        page: const ColorThemeScreen(),
      ),
      (
        icon: Icons.text_fields,
        title: l10n.textAndFontSettings,
        desc: l10n.textAndFontSettingsDesc,
        page: const FontSettingsScreen(),
      ),
      (
        icon: Icons.layers_outlined,
        title: l10n.surfaceAndBackgroundSettings,
        desc: l10n.surfaceAndBackgroundSettingsDesc,
        page: const BackgroundSettingsScreen(),
      ),
    ];

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.appearance),
          centerTitle: true,
        ),
        body: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + systemNavBottomInset(context),
          ),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return GlassCard(
              icon: category.icon,
              title: category.title,
              subtitle: category.desc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => category.page),
              ),
            );
          },
        ),
      ),
    );
  }
}
