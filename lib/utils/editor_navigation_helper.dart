import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../screens/editor_screen.dart';
import '../widgets/webview_markdown_preview.dart';

/// 统一处理进入编辑器前的预加载、初始化提示和缓存命中逻辑。
class EditorNavigationHelper {
  static Future<void> openEditor(
    BuildContext context,
    String filePath, {
    VoidCallback? onFileOpened,
    String? initialContent,
  }) async {
    final fileProvider = context.read<FileProvider>();
    final fileService = fileProvider.fileService;
    final isCached = initialContent != null || fileService.isFileCached(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;

    onFileOpened?.call();

    bool dialogShown = false;
    if (!isCached && context.mounted) {
      dialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _DocumentPreparingDialog(fileName: fileName),
      );
      // 让对话框先绘制一帧，再进行较重的初始化。
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    try {
      final preloadTasks = <Future<dynamic>>[
        warmUpMarkdownPreviewAssets(),
        initialContent != null
            ? Future<String>.value(initialContent)
            : fileService.preloadFile(filePath),
      ];
      final results = await Future.wait(preloadTasks);
      final content = results[1] as String;

      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(
            filePath: filePath,
            initialContent: content,
          ),
        ),
      );
    } catch (e) {
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开文档失败: $e')),
      );
    }
  }
}

class _DocumentPreparingDialog extends StatelessWidget {
  final String fileName;

  const _DocumentPreparingDialog({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                '正在初始化文档',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '正在预加载正文、建立缓存并预热预览引擎，稍后将直接进入可阅读状态。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
