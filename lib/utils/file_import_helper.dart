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
import '../services/my_files_service.dart';
import '../screens/editor_screen.dart';

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
  /// 
  /// 返回是否成功打开文件
  static Future<bool> openFile(
    BuildContext context,
    String filePath, {
    VoidCallback? onFileOpened,
  }) async {
    // 检查文件是否在工作区内
    final isInWorkspace = await _myFilesService.isInWorkspace(filePath);
    
    if (isInWorkspace) {
      // 文件在工作区内，直接打开
      if (!context.mounted) return false;
      _navigateToEditor(context, filePath, onFileOpened);
      return true;
    }
    
    // 文件不在工作区内，询问用户
    if (!context.mounted) return false;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _ImportDialog(fileName: _getFileName(filePath)),
    );
    
    if (result == null) {
      // 用户取消
      return false;
    }
    
    if (result == 'import') {
      // 用户选择导入
      try {
        // 对于MD文件，使用copyDocumentWithImages处理图片引用
        final isMdFile = filePath.toLowerCase().endsWith('.md') || 
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
                  Expanded(
                    child: Text(isMdFile ? '文件和引用图片已导入' : '文件已导入到我的文件'),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入失败: $e')),
          );
        }
        return false;
      }
    } else {
      // 用户选择仅查看（不导入）
      if (context.mounted) {
        _navigateToEditor(context, filePath, onFileOpened);
      }
      return true;
    }
  }

  static void _navigateToEditor(BuildContext context, String filePath, VoidCallback? onFileOpened) {
    onFileOpened?.call();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(filePath: filePath),
      ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.folder_copy,
              color: Theme.of(context).colorScheme.primary,
            ),
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
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '导入到"我的文件"后，文件将被云同步备份',
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'view'),
          child: const Text('仅查看'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'import'),
          icon: const Icon(Icons.folder_copy, size: 18),
          label: const Text('导入'),
        ),
      ],
    );
  }
}
