// ============================================================================
// 设置标签页（重构版）
// 
// 作为一级菜单，提供各设置项的入口列表
// 点击后跳转到对应的二级设置页面
// ============================================================================

import 'package:flutter/material.dart';
import '../../../utils/app_style.dart';
import '../../settings/appearance_settings_screen.dart';
import '../../settings/editor_settings_screen.dart';
import '../../settings/cloud_sync_screen.dart';
import '../../settings/storage_settings_screen.dart';
import '../../settings/about_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsHeader(context),
          const SizedBox(height: 16),

          _buildSettingsItem(
            context,
            icon: Icons.palette,
            iconColor: Colors.purple,
            title: '外观',
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
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
    required VoidCallback onTap,
  }) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
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
