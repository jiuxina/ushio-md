// ============================================================================
// 设置标签页（重构版）
//
// 作为一级菜单，提供各设置项的入口列表
// 点击后跳转到对应的二级设置页面
// ============================================================================

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/app_style.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/responsive_page_frame.dart';
import '../../settings/appearance_categories_screen.dart';
import '../../settings/editor_settings_screen.dart';
import '../../settings/cloud_sync_screen.dart';
import '../../settings/storage_settings_screen.dart';
import '../../settings/about_screen.dart';
import '../../settings/debug_settings_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePageFrame(
            maxWidth: ResponsiveLayout.isDesktopWidth(context) ? 760 : null,
            padding: ResponsiveLayout.isDesktopWidth(context)
                ? const EdgeInsets.fromLTRB(32, 24, 32, 28)
                : const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSettingsHeader(context, l10n),
                const SizedBox(height: 16),

                _buildSettingsItem(
                  context,
                  l10n: l10n,
                  icon: Icons.palette,
                  title: l10n.appearance,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppearanceCategoriesScreen(),
                    ),
                  ),
                ),

                _buildSettingsItem(
                  context,
                  l10n: l10n,
                  icon: Icons.edit,
                  title: l10n.editor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditorSettingsScreen(),
                    ),
                  ),
                ),

                _buildSettingsItem(
                  context,
                  l10n: l10n,
                  icon: Icons.cloud_sync,
                  title: l10n.cloudSync,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CloudSyncScreen()),
                  ),
                ),

                _buildSettingsItem(
                  context,
                  l10n: l10n,
                  icon: Icons.folder,
                  title: l10n.storage,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StorageSettingsScreen(),
                    ),
                  ),
                ),

                _buildSettingsItem(
                  context,
                  l10n: l10n,
                  icon: Icons.info,
                  title: l10n.about,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),

                _buildSettingsItem(
                  context,
                  l10n: l10n,
                  icon: Icons.bug_report,
                  title: l10n.debugMode,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DebugSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Icon(
            Icons.settings,
            color: Theme.of(context).colorScheme.onSurface,
            size: 26,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settings,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required AppLocalizations l10n,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    return AppSurface(
      borderRadius: BorderRadius.circular(14),
      margin: const EdgeInsets.only(bottom: 8),
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
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isDesktop ? 9 : 10,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
