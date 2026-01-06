// ============================================================================
// 设置标签页（重构版）
// 
// 作为一级菜单，提供各设置项的入口列表
// 点击后跳转到对应的二级设置页面
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../utils/constants.dart';
import '../../settings/appearance_settings_screen.dart';
import '../../settings/editor_settings_screen.dart';
import '../../settings/cloud_sync_screen.dart';
import '../../settings/storage_settings_screen.dart';
import '../../settings/about_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSettingsHeader(context),
              const SizedBox(height: 24),
              
              _buildSettingsItem(
                context,
                icon: Icons.palette,
                iconColor: Colors.purple,
                title: '外观',
                subtitle: _getThemeModeText(settings.themeMode),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.edit,
                iconColor: Colors.blue,
                title: '编辑器',
                subtitle: '字体大小: ${settings.fontSize.toInt()}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditorSettingsScreen()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.cloud_sync,
                iconColor: Colors.teal,
                title: '云同步',
                subtitle: settings.webdavUrl.isNotEmpty == true ? '已配置' : '未配置',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudSyncScreen()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.folder,
                iconColor: Colors.amber,
                title: '存储',
                subtitle: '管理工作区和缓存',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StorageSettingsScreen()),
                ),
              ),
              
              _buildSettingsItem(
                context,
                icon: Icons.info,
                iconColor: Colors.cyan,
                title: '关于',
                subtitle: 'v${AppConstants.appVersion}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '设置',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '自定义你的应用体验',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }
}
