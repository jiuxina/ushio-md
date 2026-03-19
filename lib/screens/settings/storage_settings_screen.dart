// ============================================================================
// 存储设置页面
//
// 管理缓存、清理历史记录等存储相关选项
// ============================================================================

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/my_files_service.dart';
import '../../widgets/app_background.dart';
import '../../utils/app_style.dart';

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
    // 设置 SettingsProvider 以便 MyFilesService 可以访问设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _myFilesService.setSettingsProvider(settings);
      _loadWorkspacePath();
    });
  }

  Future<void> _loadWorkspacePath() async {
    final path = await _myFilesService.getWorkspacePath();
    if (mounted) {
      setState(() => _workspacePath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('存储设置'),
          centerTitle: true,
        ),
        body: Consumer<FileProvider>(
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
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
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
    final settings = context.watch<SettingsProvider>();
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
                  Text(
                    '${settings.workspaceName} 工作区',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
        // 工作区文件夹名称设置
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('工作区文件夹名称'),
          subtitle: Text(settings.workspaceName),
          trailing: TextButton(
            onPressed: () => _showEditWorkspaceNameDialog(settings),
            child: const Text('更改'),
          ),
        ),
        const SizedBox(height: 12),
        // 基础路径自定义设置
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自定义基础路径（高级）'),
          subtitle: Text(
            settings.customWorkspaceBasePath ?? '使用默认路径',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.customWorkspaceBasePath != null)
                TextButton(
                  onPressed: () => _clearCustomBasePath(settings),
                  child: const Text('重置'),
                ),
              TextButton(
                onPressed: () => _showEditBasePathDialog(settings),
                child: const Text('更改'),
              ),
            ],
          ),
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
                  '工作区文件会自动同步到云端',
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

  void _showEditWorkspaceNameDialog(SettingsProvider settings) {
    final controller = TextEditingController(text: settings.workspaceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('更改工作区名称'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入新的工作区文件夹名称：'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ushio-md',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '注意：更改名称后需要重新配置云同步',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称不能为空')),
                );
                return;
              }
              if (newName.contains('/') || newName.contains('\\')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称不能包含斜杠')),
                );
                return;
              }
              Navigator.pop(context);
              await settings.setWorkspaceName(newName);
              // 重新加载工作区路径
              await _loadWorkspacePath();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green),
                        const SizedBox(width: 12),
                        Text('工作区名称已更新为 $newName'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showEditBasePathDialog(SettingsProvider settings) async {
    // 获取默认路径用于显示
    final externalDir = await getExternalStorageDirectory();
    final defaultPath = externalDir?.path ?? '/storage/emulated/0/Documents';

    final controller = TextEditingController(
      text: settings.customWorkspaceBasePath ?? '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_location,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('自定义基础路径')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入自定义的基础路径：'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: defaultPath,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                      '默认路径：$defaultPath',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_outlined, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '警告：更改基础路径将影响工作区位置，请确保路径存在且可访问',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newPath = controller.text.trim();
              Navigator.pop(context);
              await settings.setCustomWorkspaceBasePath(
                newPath.isEmpty ? null : newPath,
              );
              // 清除缓存并重新加载路径
              _myFilesService.setSettingsProvider(settings);
              await _loadWorkspacePath();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green),
                        const SizedBox(width: 12),
                        Text(newPath.isEmpty ? '已重置为默认路径' : '基础路径已更新'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _clearCustomBasePath(SettingsProvider settings) async {
    await settings.setCustomWorkspaceBasePath(null);
    // 清除缓存并重新加载路径
    _myFilesService.setSettingsProvider(settings);
    await _loadWorkspacePath();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check, color: Colors.green),
              SizedBox(width: 12),
              Text('已重置为默认路径'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
