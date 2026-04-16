import 'package:flutter/material.dart';
import '../../../providers/file_provider.dart';
import '../../../utils/file_actions.dart';
import '../../../utils/file_import_helper.dart';
import '../../../utils/app_style.dart';

import '../../../screens/folder_browser_screen.dart';

class QuickActions extends StatelessWidget {
  final FileProvider fileProvider;
  final VoidCallback? onRefresh;

  const QuickActions({super.key, required this.fileProvider, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    bool hasPinnedItems =
        fileProvider.pinnedFiles.isNotEmpty ||
        fileProvider.pinnedFolders.isNotEmpty;

    if (hasPinnedItems) {
      return _buildCompactQuickActions(context);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: appStyle.surfaceShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '快速操作',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // First row
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  icon: Icons.add_circle,
                  label: '新建文件',
                  color: Colors.green,
                  onTap: () => FileActions.showCreateFileDialog(
                    context,
                    fileProvider,
                    onRefresh: onRefresh,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  icon: Icons.create_new_folder,
                  label: '新建文件夹',
                  color: Colors.orange,
                  onTap: () =>
                      FileActions.showCreateFolderDialog(context, fileProvider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  icon: Icons.file_open,
                  label: '打开文件',
                  color: Colors.blue,
                  onTap: () async {
                    final path = await fileProvider.pickAndOpenFile();
                    if (path != null && context.mounted) {
                      FileImportHelper.openFile(
                        context,
                        path,
                        onFileOpened: () => fileProvider.addToRecentFiles(path),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  icon: Icons.folder_open,
                  label: '打开文件夹',
                  color: Colors.amber,
                  onTap: () async {
                    final path = await fileProvider.pickDirectory();
                    if (path != null) {
                      await fileProvider.addToRecentFolders(path);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FolderBrowserScreen(folderPath: path),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuickActions(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: appStyle.surfaceShadow,
        gradient: LinearGradient(
          begin: Alignment.centerLeft, // Horizontal gradient for compact row
          end: Alignment.centerRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactIconButton(
            context,
            icon: Icons.add_circle,
            color: Colors.green,
            tooltip: '新建文件',
            onTap: () => FileActions.showCreateFileDialog(
              context,
              fileProvider,
              onRefresh: onRefresh,
            ),
          ),
          _buildCompactIconButton(
            context,
            icon: Icons.create_new_folder,
            color: Colors.orange,
            tooltip: '新建文件夹',
            onTap: () =>
                FileActions.showCreateFolderDialog(context, fileProvider),
          ),
          _buildCompactIconButton(
            context,
            icon: Icons.file_open,
            color: Colors.blue,
            tooltip: '打开文件',
            onTap: () async {
              final path = await fileProvider.pickAndOpenFile();
              if (path != null && context.mounted) {
                FileImportHelper.openFile(
                  context,
                  path,
                  onFileOpened: () => fileProvider.addToRecentFiles(path),
                );
              }
            },
          ),
          _buildCompactIconButton(
            context,
            icon: Icons.folder_open,
            color: Colors.amber,
            tooltip: '打开文件夹',
            onTap: () async {
              final path = await fileProvider.pickDirectory();
              if (path != null) {
                await fileProvider.addToRecentFolders(path);
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FolderBrowserScreen(folderPath: path),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIconButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: appStyle.surfaceDecoration(
            borderRadius: BorderRadius.circular(16),
            color: appStyle.scaledSurfaceColor(
              Theme.of(context).colorScheme,
              alpha: 0.8,
            ),
            border: appStyle.useBorderlessButtons
                ? null
                : Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
