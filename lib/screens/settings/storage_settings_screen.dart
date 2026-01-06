// ============================================================================
// 存储设置页面
// 
// 管理缓存、清理历史记录等存储相关选项
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/my_files_service.dart';
import '../../widgets/app_background.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final MyFilesService _myFilesService = MyFilesService();
  String _workspacePath = '';

  @override
  void initState() {
    super.initState();
    _loadWorkspacePath();
  }

  Future<void> _loadWorkspacePath() async {
    final path = await _myFilesService.getWorkspacePath();
    if (mounted) {
      setState(() => _workspacePath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储设置'),
        centerTitle: true,
      ),
      body: AppBackground(
        child: Consumer<FileProvider>(
          builder: (context, fileProvider, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection('我的文件', Icons.folder_special, [
                  _buildWorkspaceInfo(),
                  const SizedBox(height: 12),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      return ListTile(
                        title: const Text('新建文件默认位置'),
                        subtitle: Text(
                          settings.defaultDirectory ?? '未设置 (默认使用当前或最近位置)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final path = await fileProvider.pickDirectory();
                            if (path != null) {
                              settings.setDefaultDirectory(path);
                            }
                          },
                          child: const Text('更改'),
                        ),
                        onLongPress: () {
                          // 长按清除
                          settings.setDefaultDirectory(null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已重置默认位置')),
                          );
                        },
                      );
                    }
                  ),
                ]),
                
                const SizedBox(height: 16),
                
                _buildSection('清理', Icons.cleaning_services, [
                  _buildClearRecentFilesButton(fileProvider),
                  const SizedBox(height: 12),
                  _buildClearRecentFoldersButton(fileProvider),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildWorkspaceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ushio-MD 工作区',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _workspacePath.isEmpty ? '加载中...' : _workspacePath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '此目录中的文件会自动同步到云端',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClearRecentFilesButton(FileProvider fileProvider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.history, color: Colors.red),
      ),
      title: const Text('清除最近文件'),
      subtitle: Text('${fileProvider.recentFiles.length} 个文件'),
      trailing: TextButton(
        onPressed: fileProvider.recentFiles.isEmpty
            ? null
            : () => _showClearConfirmDialog(
                  context,
                  '清除最近文件',
                  '确定要清除所有最近访问的文件记录吗？',
                  () => fileProvider.clearRecentFiles(),
                ),
        child: const Text('清除'),
      ),
    );
  }

  Widget _buildClearRecentFoldersButton(FileProvider fileProvider) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.folder_open, color: Colors.orange),
      ),
      title: const Text('清除最近文件夹'),
      subtitle: Text('${fileProvider.recentFolders.length} 个文件夹'),
      trailing: TextButton(
        onPressed: fileProvider.recentFolders.isEmpty
            ? null
            : () => _showClearConfirmDialog(
                  context,
                  '清除最近文件夹',
                  '确定要清除所有最近访问的文件夹记录吗？',
                  () => fileProvider.clearRecentFolders(),
                ),
        child: const Text('清除'),
      ),
    );
  }

  void _showClearConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.green),
                      const SizedBox(width: 12),
                      const Text('已清除'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
