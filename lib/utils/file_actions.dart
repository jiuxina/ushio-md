import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../services/share_service.dart';
import '../services/export_service.dart';
import '../screens/editor_screen.dart';
import '../screens/folder_browser_screen.dart';
import '../providers/plugin_provider.dart';
import '../plugins/extensions/file_action_extension.dart';

enum FileSource {
  myFiles,
  pinned,
  history,
}

class FileActions {
  static void showFileContextMenu(
    BuildContext context, 
    String path, 
    FileProvider fileProvider, 
    {bool isRecent = false, bool isPinned = false, VoidCallback? onRefresh, FileSource? source}
  ) {
    final shareService = ShareService();
    final fileName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFilePinned(path);
    // Use source if provided, otherwise infer from bools (for backward compatibility if any)
    final effectiveSource = source ?? (isPinned ? FileSource.pinned : (isRecent ? FileSource.history : FileSource.myFiles));
    
    final pluginProvider = context.read<PluginProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fileName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            
            // 1. Share (With submenu for file share options)
            _buildShareSubmenu(context, path, shareService),
            const SizedBox(height: 8),

            // 2. Rename (All sources)
            _buildContextMenuItem(
              context,
              icon: Icons.edit,
              label: '重命名',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                showRenameDialog(context, path, fileProvider, onRefresh: onRefresh);
              },
            ),
            const SizedBox(height: 8),

            // 3. Pin/Unpin (All sources - Logic varies slightly)
            // Pinned: Cancel Top (Unpin)
            // Others: Pin/Unpin Toggle
            _buildContextMenuItem(
              context,
              icon: isCurrentlyPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                fileProvider.togglePinFile(path);
              },
            ),
            const SizedBox(height: 8),

            // 4. Delete / Remove (Source dependent)
            if (effectiveSource == FileSource.myFiles)
              _buildContextMenuItem(
                context,
                icon: Icons.delete,
                label: '删除文件',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  confirmDelete(context, path, fileProvider, onRefresh: onRefresh);
                },
              ),
            
            if (effectiveSource == FileSource.history)
              _buildContextMenuItem(
                context,
                icon: Icons.history, // Icon for remove from history
                label: '移除记录',
                color: Colors.red, // Or orange/grey? Red implies destructive usually.
                onTap: () {
                  Navigator.pop(context);
                  fileProvider.removeFromRecentFiles(path);
                },
              ),
              
            // Pinned: No delete/remove option requested
            // So we add nothing else for pinned.

            // 5. Plugin Actions
            ...pluginProvider.getFileActionExtensions().where((ext) => ext.supportsFile(path)).map((ext) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildContextMenuItem(
                  context,
                  icon: ext.iconData,
                  label: ext.actionName,
                  color: Colors.teal, // Plugin default color
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('插件操作: ${ext.actionName} (ID: ${ext.actionId})')),
                    );
                    // TODO: Execute plugin script
                  },
                ),
              );
            }),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static void showFolderContextMenu(
    BuildContext context, 
    String path, 
    FileProvider fileProvider, 
    {bool isPinned = false, FileSource? source, VoidCallback? onRefresh}
  ) {
    // folders usually don't support simple share unless zipped. 
    // Assuming we might want to implement zip share later or share path string.
    // For now, adding the visual option as requested.
    final shareService = ShareService(); 
    final pluginProvider = context.read<PluginProvider>();

    final folderName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFolderPinned(path);
    final effectiveSource = source ?? (isPinned ? FileSource.pinned : FileSource.myFiles); 
    // Note: Folder browser history (?) - history tab has folders? Yes "Recent Folders".
    // So if it's from history tab, source is history.

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              folderName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // 1. Share folder as ZIP
            _buildContextMenuItem(
              context,
              icon: Icons.folder_zip,
              label: '分享文件夹 (ZIP)',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                final success = await shareService.shareFolder(path);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 12),
                          Text('压缩分享失败'),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),

            // 2. Rename (All sources)
            _buildContextMenuItem(
              context,
              icon: Icons.edit,
              label: '重命名',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                showRenameFolderDialog(context, path, fileProvider, onRefresh: onRefresh);
              },
            ),
            const SizedBox(height: 8),

            // 3. Pin/Unpin (All sources)
            _buildContextMenuItem(
              context,
              icon: isCurrentlyPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                fileProvider.togglePinFolder(path);
              },
            ),
            const SizedBox(height: 8),

            // 4. Delete / Remove (Source dependent)
            if (effectiveSource == FileSource.myFiles)
              _buildContextMenuItem(
                context,
                icon: Icons.delete,
                label: '删除文件夹',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  confirmDeleteFolder(context, path, fileProvider, onRefresh: onRefresh);
                },
              ),
            
            if (effectiveSource == FileSource.history)
              _buildContextMenuItem(
                context,
                icon: Icons.history, 
                label: '移除记录',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  fileProvider.removeFromRecentFolders(path);
                },
              ),

             // Pinned folders: No delete option requested.

            // 5. Plugin Actions (Folders)
            ...pluginProvider.getFileActionExtensions().where((ext) => ext.supportsFile(path) && ext.actionType == FileActionType.custom).map((ext) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildContextMenuItem(
                  context,
                  icon: ext.iconData,
                  label: ext.actionName,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('插件操作: ${ext.actionName} (ID: ${ext.actionId})')),
                    );
                  },
                ),
              );
            }),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  static Widget _buildContextMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建文件分享子菜单
  /// 
  /// 提供三种分享选项：
  /// - 以文件分享：直接分享 .md 文件
  /// - 以图片分享：渲染 Markdown 为图片后分享（待实现）
  /// - 以 PDF 分享：转换为 PDF 后分享（待实现）
  static Widget _buildShareSubmenu(BuildContext context, String path, ShareService shareService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.share, color: Colors.blue),
          title: const Text(
            '分享',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          children: [
            // 以文件分享
            _buildShareOption(
              context,
              icon: Icons.insert_drive_file,
              label: '以文件分享',
              subtitle: '分享 .md 原文件',
              onTap: () {
                Navigator.pop(context);
                shareService.shareFile(path);
              },
            ),
            const SizedBox(height: 8),
            // 以图片分享
            _buildShareOption(
              context,
              icon: Icons.image,
              label: '以图片分享',
              subtitle: '请在编辑器全屏预览中使用',
              isDisabled: true,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('请打开文件后，在全屏预览模式中使用分享按钮导出图片'),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // 以 PDF 分享
            _buildShareOption(
              context,
              icon: Icons.picture_as_pdf,
              label: '以 PDF 分享',
              subtitle: '转换为 PDF 后分享',
              onTap: () async {
                Navigator.pop(context);
                // 读取文件内容
                try {
                  final file = File(path);
                  final content = await file.readAsString();
                  final fileName = path.split(Platform.pathSeparator).last.replaceAll('.md', '').replaceAll('.markdown', '');
                  
                  // 显示加载提示
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('正在生成 PDF...'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  
                  final success = await ExportService.exportAndShareAsPdf(
                    content,
                    fileName,
                    title: fileName,
                  );
                  
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 12),
                            Text('PDF 导出失败'),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('无法读取文件: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建分享选项
  static Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final color = isDisabled ? Colors.grey : Colors.blue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDisabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '待开发',
                    style: TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  static Future<void> showRenameDialog(BuildContext context, String path, FileProvider fileProvider, {VoidCallback? onRefresh}) async {

    final fileName = path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.replaceAll('.md', '').replaceAll('.markdown', '');
    final controller = TextEditingController(text: nameWithoutExt);
    
    // 非法字符正则（文件名不能包含以下字符）
    final illegalCharsRegex = RegExp(r'[\\/:*?"<>|]');
    String? errorText;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('重命名文件'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '新文件名',
                    suffixText: '.md',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: errorText,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorText = '文件名不能为空';
                      } else if (illegalCharsRegex.hasMatch(value)) {
                        errorText = '文件名不能包含 \\ / : * ? " < > |';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: errorText == null && controller.text.isNotEmpty
                    ? () => Navigator.pop(context, controller.text)
                    : null,
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty && result != nameWithoutExt) {
      try {
        final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
        final newPath = '$dir${Platform.pathSeparator}$result.md';
        final file = File(path);
        await file.rename(newPath);
        fileProvider.refresh();
        onRefresh?.call();
      } catch (e) {

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败: $e')),
          );
        }
      }
    }
  }

  static Future<void> confirmDelete(BuildContext context, String path, FileProvider fileProvider, {VoidCallback? onRefresh}) async {

    final fileName = path.split(Platform.pathSeparator).last;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除文件'),
        content: Text('确定要删除 "$fileName" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await fileProvider.deleteFile(path);
      onRefresh?.call();
    }

  }

  static Future<void> showCreateFileInFolderDialog(BuildContext context, String folderPath, FileProvider fileProvider) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('新建文件'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '文件名',
            suffixText: '.md',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final file = await fileProvider.createFile(folderPath, result);
      if (file != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(filePath: file.path),
          ),
        );
      }
    }
  }

  static Future<void> showCreateFileDialog(BuildContext context, FileProvider fileProvider) async {
    final nameController = TextEditingController();
    final settings = context.read<SettingsProvider>();
    
    // Determine default path priority:
    // 1. Current directory (if explicitly set/known preference in dialog context? No, usually derived)
    // 2. User defined default directory
    // 3. First recent folder
    // Note: fileProvider.currentDirectory might be null if we are at root or not browsing.
    String? selectedPath = fileProvider.currentDirectory;
    
    if (selectedPath == null) {
       if (settings.defaultDirectory != null && Directory(settings.defaultDirectory!).existsSync()) {
         selectedPath = settings.defaultDirectory;
       } else if (fileProvider.recentFolders.isNotEmpty) {
         selectedPath = fileProvider.recentFolders.first;
       }
    }
    
    // If still null, try to use root path? 
    // fileProvider doesn't track root path visibly here, but the dialog allows picking.

    if (selectedPath == null && fileProvider.recentFolders.isNotEmpty) {
      selectedPath = fileProvider.recentFolders.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('新建 Markdown'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '文件名',
                    hintText: '例如: 我的笔记',
                    suffixText: '.md',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '保存位置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final path = await fileProvider.fileService.pickDirectory();
                    if (path != null) {
                      setDialogState(() => selectedPath = path);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPath ?? '点击选择文件夹',
                            style: TextStyle(
                              color: selectedPath != null
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: selectedPath == null || nameController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'name': nameController.text,
                        'path': selectedPath!,
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final file = await fileProvider.createFile(
        result['path']!,
        result['name']!,
      );
      if (file != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(filePath: file.path),
          ),
        );
      }
    }
  }

  static Future<void> showCreateFolderDialog(BuildContext context, FileProvider fileProvider) async {
    final nameController = TextEditingController();
    final settings = context.read<SettingsProvider>();
    
    String? selectedPath = fileProvider.currentDirectory;
    
    if (selectedPath == null) {
       if (settings.defaultDirectory != null && Directory(settings.defaultDirectory!).existsSync()) {
         selectedPath = settings.defaultDirectory;
       } else if (fileProvider.recentFolders.isNotEmpty) {
         selectedPath = fileProvider.recentFolders.first;
       }
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.create_new_folder, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('新建文件夹'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '文件夹名称',
                    hintText: '例如: 我的笔记',
                    prefixIcon: const Icon(Icons.folder),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '创建位置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final path = await fileProvider.fileService.pickDirectory();
                    if (path != null) {
                      setDialogState(() => selectedPath = path);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPath ?? '点击选择位置',
                            style: TextStyle(
                              color: selectedPath != null
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: selectedPath == null || nameController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'name': nameController.text,
                        'path': selectedPath!,
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final newFolderPath = '${result['path']}${Platform.pathSeparator}${result['name']}';
        await Directory(newFolderPath).create(recursive: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件夹 "${result['name']}" 创建成功')),
          );
          // Navigate to the new folder
          await fileProvider.addToRecentFolders(newFolderPath);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderBrowserScreen(folderPath: newFolderPath),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }


  static Future<void> showRenameFolderDialog(BuildContext context, String path, FileProvider fileProvider, {VoidCallback? onRefresh}) async {
    final folderName = path.split(Platform.pathSeparator).last;
    final controller = TextEditingController(text: folderName);
    
    // 非法字符正则（文件夹名不能包含以下字符）
    final illegalCharsRegex = RegExp(r'[\\/:*?"<>|]');
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('重命名文件夹'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '新文件夹名',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: errorText,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorText = '文件夹名不能为空';
                      } else if (illegalCharsRegex.hasMatch(value)) {
                        errorText = '文件夹名不能包含 \\ / : * ? " < > |';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: errorText == null && controller.text.isNotEmpty
                    ? () => Navigator.pop(context, controller.text)
                    : null,
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty && result != folderName) {
      try {
        final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
        final newPath = '$dir${Platform.pathSeparator}$result';
        final directory = Directory(path);
        await directory.rename(newPath);
        fileProvider.refresh();
        onRefresh?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败: $e')),
          );
        }
      }
    }
  }

  static Future<void> confirmDeleteFolder(BuildContext context, String path, FileProvider fileProvider, {VoidCallback? onRefresh}) async {
    final folderName = path.split(Platform.pathSeparator).last;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除文件夹'),
        content: Text('确定要删除 "$folderName" 及其所有内容吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await fileProvider.deleteFolder(path);
      onRefresh?.call();
    }
  }
}
