import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../screens/editor_screen.dart';
import '../widgets/themed_feedback.dart';
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
        builder: (dialogContext) => ThemedProgressDialog(
          title: '正在初始化文档',
          label: fileName,
          message: '正在预加载正文、建立缓存并预热预览引擎，稍后将直接进入可阅读状态。',
          icon: Icons.menu_book_rounded,
        ),
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

      showThemedSnackBar(
        context,
        message: '打开文档失败: $e',
        icon: Icons.error_outline_rounded,
        accentColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
