import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/file_provider.dart';
import '../../../utils/file_actions.dart';
import '../../editor_screen.dart';
import '../../folder_browser_screen.dart';

class FileTile extends StatelessWidget {
  final FileSystemEntity entity;
  final VoidCallback? onRefresh;
  final bool isDraggable;
  final int? index;
  final FileSource source;

  const FileTile({
    super.key,
    required this.entity,
    this.onRefresh,
    this.isDraggable = false,
    this.index,
    this.source = FileSource.myFiles,
  });

  @override
  Widget build(BuildContext context) {
    final isFile = entity is File;
    final name = entity.path.split(Platform.pathSeparator).last;
    final isImage = isFile && _isImage(name);
    final isPinned = source == FileSource.pinned;
    
    // 获取文件/文件夹信息 (日期/大小)
    String subtitle = '';
    try {
      final stat = entity.statSync();
      // 对于文件夹，显示路径；对于文件，显示路径或大小
      if (isFile) {
        final date = stat.modified;
        final formattedDate = '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        subtitle = '${_formatSize(stat.size)} · $formattedDate';
      } else {
        subtitle = entity.path;
      }
    } catch (_) {
        subtitle = entity.path;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPinned 
              ? (isFile ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3))
              : Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isFile) {
              if (name.toLowerCase().endsWith('.md')) {
                final fileProvider = context.read<FileProvider>();
                fileProvider.addToRecentFiles(entity.path);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditorScreen(filePath: entity.path),
                  ),
                );
              } else if (isImage) {
                _showImagePreview(context, entity.path);
              }
            } else {
              final fileProvider = context.read<FileProvider>();
              fileProvider.addToRecentFolders(entity.path);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderBrowserScreen(folderPath: entity.path),
                ),
              );
            }
          },
          onLongPress: () {
            final fileProvider = context.read<FileProvider>();
            if (isFile) {
              FileActions.showFileContextMenu(
                context, 
                entity.path, 
                fileProvider,
                onRefresh: onRefresh,
                source: source,
              );
            } else {
              FileActions.showFolderContextMenu(
                context, 
                entity.path, 
                fileProvider,
                source: source,
                onRefresh: onRefresh,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildIcon(context, isFile, isImage, isPinned),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isDraggable && index != null)
                  ReorderableDelayedDragStartListener(
                    index: index!,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Icon(
                        Icons.drag_handle,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                else
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

  void _showImagePreview(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
             // Modal Barrier (Dark)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Image
            InteractiveViewer(
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
              ),
            ),
            // Actions (Optional)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, bool isFile, bool isImage, bool isPinned) {
    IconData iconData;
    Color iconColor;
    
    if (!isFile) {
      iconData = Icons.folder;
      iconColor = Colors.amber;
    } else if (isImage) {
      iconData = Icons.image;
      iconColor = Colors.purple;
    } else {
      iconData = Icons.description;
      iconColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || 
           lower.endsWith('.jpeg') || 
           lower.endsWith('.png') || 
           lower.endsWith('.gif') || 
           lower.endsWith('.webp');
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
