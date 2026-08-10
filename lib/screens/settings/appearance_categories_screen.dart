// ============================================================================
// 外观设置分类页面（第二层）
//
// 展示外观设置的分类列表，点击后跳转到对应的子设置页面（第三层）
// ============================================================================

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/app_style.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_surface.dart';
import 'appearance/theme_settings_screen.dart';
import 'appearance/font_settings_screen.dart';
import 'appearance/background_settings_screen.dart';
import 'appearance/other_appearance_settings_screen.dart';

class AppearanceCategoriesScreen extends StatelessWidget {
  const AppearanceCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.appearance),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 主题设置
            _buildCategoryItem(
              context,
              appStyle: appStyle,
              icon: Icons.palette_outlined,
              title: l10n.themeSettings,
              description: l10n.themeSettingsDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              ),
            ),

            const SizedBox(height: 8),

            // 字体设置
            _buildCategoryItem(
              context,
              appStyle: appStyle,
              icon: Icons.font_download_outlined,
              title: l10n.fontSettings,
              description: l10n.fontSettingsDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FontSettingsScreen()),
              ),
            ),

            const SizedBox(height: 8),

            // 背景设置
            _buildCategoryItem(
              context,
              appStyle: appStyle,
              icon: Icons.image_outlined,
              title: l10n.backgroundSettings,
              description: l10n.backgroundSettingsDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BackgroundSettingsScreen(),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 其他设置
            _buildCategoryItem(
              context,
              appStyle: appStyle,
              icon: Icons.more_horiz,
              title: l10n.otherAppearanceSettings,
              description: l10n.otherAppearanceSettingsDesc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OtherAppearanceSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required AppStyleTheme appStyle,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return AppSurface(
      borderRadius: BorderRadius.circular(14),
      color: appStyle.scaledSurfaceColor(
        Theme.of(context).colorScheme,
        alpha: 0.7,
      ),
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(icon, color: context.appIconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
