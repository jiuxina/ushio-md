import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../screens/editor_screen.dart';
import '../widgets/milkdown_webview_editor.dart';
import '../widgets/themed_feedback.dart';

/// 统一处理进入编辑器前的预加载、初始化提示和缓存命中逻辑。
class EditorNavigationHelper {
  static bool _isOpeningDocument = false;

  static Future<void> openEditor(
    BuildContext context,
    String filePath, {
    VoidCallback? onFileOpened,
    String? initialContent,
  }) async {
    if (_isOpeningDocument) return;
    _isOpeningDocument = true;

    final fileProvider = context.read<FileProvider>();
    final fileService = fileProvider.fileService;
    final isCached =
        initialContent != null || fileService.isFileCached(filePath);
    BuildContext? dialogContext;

    onFileOpened?.call();

    bool dialogShown = false;
    if (!isCached && context.mounted) {
      dialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (currentDialogContext) {
          dialogContext = currentDialogContext;
          return const ThemedProgressDialog(
            title: '正在初始化文档',
            icon: Icons.menu_book_rounded,
          );
        },
      );
      // 让对话框先绘制一帧，再进行较重的初始化。
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    try {
      final preloadTasks = <Future<dynamic>>[
        warmUpMilkdownWebAssets().timeout(const Duration(seconds: 8)),
        initialContent != null
            ? Future<String>.value(initialContent)
            : fileService.preloadFile(filePath).timeout(
                const Duration(seconds: 8),
              ),
      ];
      final results = await Future.wait(preloadTasks);
      final content = results[1] as String;

      _dismissDialog(dialogShown, dialogContext, context);
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
      _dismissDialog(dialogShown, dialogContext, context);
      if (!context.mounted) return;

      showThemedSnackBar(
        context,
        message: '打开文档失败: $e',
        icon: Icons.error_outline_rounded,
        accentColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _dismissDialog(dialogShown, dialogContext, context);
      _isOpeningDocument = false;
    }
  }

  static void _dismissDialog(
    bool dialogShown,
    BuildContext? dialogContext,
    BuildContext fallbackContext,
  ) {
    if (!dialogShown) return;

    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
      return;
    }

    if (fallbackContext.mounted) {
      final navigator = Navigator.of(fallbackContext, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}
