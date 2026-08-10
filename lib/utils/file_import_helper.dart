// ============================================================================
// 文件导入助手
//
// 处理外部文件的导入逻辑：
// - 检查文件是否在"我的文件"工作区内
// - 如果不在，提示用户是否要导入到工作区
// - 导入文件到工作区
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/my_files_service.dart';
import 'editor_navigation_helper.dart';

/// 文件导入结果
class FileImportResult {
  /// 导入后的文件路径（如果导入了的话）
  final String? importedPath;

  /// 是否成功打开
  final bool success;

  /// 是否为新导入的文件
  final bool wasImported;

  const FileImportResult({
    this.importedPath,
    required this.success,
    this.wasImported = false,
  });
}

/// 文件导入助手
///
/// 提供统一的外部文件导入处理逻辑
class FileImportHelper {
  static final MyFilesService _myFilesService = MyFilesService();

  /// 打开文件（如需要会提示导入）
  ///
  /// [context] 上下文
  /// [filePath] 文件路径
  /// [onFileOpened] 文件打开后的回调（用于添加到最近文件等）
  /// [onImportComplete] 导入完成后的回调（用于刷新文件列表等）
  ///
  /// 返回导入结果
  static Future<FileImportResult> openFile(
    BuildContext context,
    String filePath, {
    VoidCallback? onFileOpened,
    VoidCallback? onImportComplete,
  }) async {
    // Ensure MyFilesService has SettingsProvider for correct path resolution
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _myFilesService.setSettingsProvider(settings);
    } catch (e) {
      debugPrint(
        'FileImportHelper: SettingsProvider not available, using defaults: $e',
      );
    }

    // 检查文件是否在工作区内
    final isInWorkspace = await _myFilesService.isInWorkspace(filePath);

    if (isInWorkspace) {
      // 文件在工作区内，直接打开
      if (!context.mounted) return const FileImportResult(success: false);
      _navigateToEditor(context, filePath, onFileOpened);
      return FileImportResult(importedPath: filePath, success: true);
    }

    // 文件不在工作区内，询问用户
    if (!context.mounted) return const FileImportResult(success: false);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ImportDialog(fileName: _getFileName(filePath)),
    );

    if (result == null) {
      // 用户取消
      return const FileImportResult(success: false);
    }

    if (result == 'import') {
      // 用户选择导入
      try {
        // 对于MD文件，使用copyDocumentWithImages处理图片引用
        final isMdFile =
            filePath.toLowerCase().endsWith('.md') ||
            filePath.toLowerCase().endsWith('.markdown');
        final newPath = isMdFile
            ? await _myFilesService.copyDocumentWithImages(filePath)
            : await _myFilesService.copyToWorkspace(filePath);

        if (context.mounted) {
          _navigateToEditor(context, newPath, onFileOpened);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(child: Text(isMdFile ? '文件和引用图片已导入' : '文件已导入到我的文件')),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        // 通知刷新文件列表
        onImportComplete?.call();

        return FileImportResult(
          importedPath: newPath,
          success: true,
          wasImported: true,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
        }
        return const FileImportResult(success: false);
      }
    } else {
      // 用户选择仅查看（不导入）
      if (context.mounted) {
        _navigateToEditor(context, filePath, onFileOpened);
      }
      return FileImportResult(importedPath: filePath, success: true);
    }
  }

  static void _navigateToEditor(
    BuildContext context,
    String filePath,
    VoidCallback? onFileOpened,
  ) {
    EditorNavigationHelper.openEditor(
      context,
      filePath,
      onFileOpened: onFileOpened,
    );
  }

  static String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}

/// 导入确认对话框
class _ImportDialog extends StatelessWidget {
  final String fileName;

  const _ImportDialog({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.folder_copy,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          const Flexible(child: Text('导入到我的文件？')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件 "$fileName" 是外部文件。',
            style: const TextStyle(fontWeight: FontWeight.w500),
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '导入到"我的文件"后，文件将被云同步备份',
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
        SizedBox(
          width: double.infinity,
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'view'),
                child: const Text('仅查看', maxLines: 1, softWrap: false),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'import'),
                child: const Text('导入'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
