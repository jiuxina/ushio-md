// ============================================================================
// 存储设置页面
//
// 管理缓存、清理历史记录等存储相关选项
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/my_files_service.dart';
import '../../widgets/app_background.dart';
import '../../utils/app_style.dart';
import '../../widgets/app_surface.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.storageSettings),
          centerTitle: true,
        ),
        body: Consumer<FileProvider>(
          builder: (context, fileProvider, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(l10n.myFiles, Icons.folder_special, [
                  _buildWorkspaceInfo(l10n),
                  const SizedBox(height: 12),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      return ListTile(
                        title: Text(l10n.newFileDefaultLocation),
                        subtitle: Text(
                          settings.defaultDirectory ??
                              l10n.notSetUseCurrentOrRecent,
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
                          child: Text(l10n.change),
                        ),
                        onLongPress: () {
                          // 长按清除
                          settings.setDefaultDirectory(null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.defaultLocationReset)),
                          );
                        },
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                _buildSection(l10n.cleanup, Icons.cleaning_services, [
                  _buildClearRecentFilesButton(fileProvider, l10n),
                  const SizedBox(height: 12),
                  _buildClearRecentFoldersButton(fileProvider, l10n),
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
    return AppSurface(
      padding: const EdgeInsets.all(16),
      color: appStyle.scaledSurfaceColor(
        Theme.of(context).colorScheme,
        alpha: 0.7,
      ),
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildWorkspaceInfo(AppLocalizations l10n) {
    final settings = context.watch<SettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.folder,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settings.workspaceName} ${l10n.workspace}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _workspacePath.isEmpty ? l10n.loading : _workspacePath,
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
          title: Text(l10n.workspaceFolderName),
          subtitle: Text(settings.workspaceName),
          trailing: TextButton(
            onPressed: () => _showEditWorkspaceNameDialog(settings, l10n),
            child: Text(l10n.change),
          ),
        ),
        const SizedBox(height: 12),
        // 基础路径自定义设置
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.customBasePathAdvanced),
          subtitle: Text(
            settings.customWorkspaceBasePath ?? l10n.useDefaultPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.customWorkspaceBasePath != null)
                TextButton(
                  onPressed: () => _clearCustomBasePath(settings, l10n),
                  child: Text(l10n.reset),
                ),
              TextButton(
                onPressed: () => _showEditBasePathDialog(settings, l10n),
                child: Text(l10n.change),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.workspaceFilesSyncToCloud,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClearRecentFilesButton(
    FileProvider fileProvider,
    AppLocalizations l10n,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.history,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(l10n.clearRecentFiles),
      subtitle: Text(l10n.filesCount(fileProvider.recentFiles.length)),
      trailing: TextButton(
        onPressed: fileProvider.recentFiles.isEmpty
            ? null
            : () => _showClearConfirmDialog(
                context,
                l10n.clearRecentFiles,
                l10n.confirmClearRecentFiles,
                () => fileProvider.clearRecentFiles(),
                l10n,
              ),
        child: Text(l10n.clear),
      ),
    );
  }

  Widget _buildClearRecentFoldersButton(
    FileProvider fileProvider,
    AppLocalizations l10n,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.folder_open,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(l10n.clearRecentFolders),
      subtitle: Text(l10n.foldersCount(fileProvider.recentFolders.length)),
      trailing: TextButton(
        onPressed: fileProvider.recentFolders.isEmpty
            ? null
            : () => _showClearConfirmDialog(
                context,
                l10n.clearRecentFolders,
                l10n.confirmClearRecentFolders,
                () => fileProvider.clearRecentFolders(),
                l10n,
              ),
        child: Text(l10n.clear),
      ),
    );
  }

  void _showClearConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
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
                      Text(l10n.cleared),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showEditWorkspaceNameDialog(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final controller = TextEditingController(text: settings.workspaceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Text(l10n.changeWorkspaceName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.inputWorkspaceFolderName),
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.warningChangeNameRequiresCloudSync,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.nameCannotBeEmpty)));
                return;
              }
              if (newName.contains('/') || newName.contains('\\')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.nameCannotContainSlash)),
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
                        Text(l10n.workspaceNameUpdated(newName)),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showEditBasePathDialog(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) async {
    // 使用 MyFilesService 获取正确的默认工作区路径
    // 这样可以确保显示的默认路径与实际使用的路径一致
    final defaultPath = await _myFilesService.getWorkspacePath();

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
            Icon(
              Icons.edit_location,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(l10n.customBasePath),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.inputCustomBasePath),
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.defaultPath(defaultPath),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.warningChangeBasePathAffectsWorkspace,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            child: Text(l10n.cancel),
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
                        Text(
                          newPath.isEmpty
                              ? l10n.resetToDefaultPath
                              : l10n.basePathUpdated,
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _clearCustomBasePath(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) async {
    await settings.setCustomWorkspaceBasePath(null);
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
              Text(l10n.resetToDefaultPath),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
