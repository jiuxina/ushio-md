import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../screens/editor_screen.dart';
import '../widgets/milkdown_webview_editor.dart';
import '../widgets/themed_feedback.dart';
import 'debug_log.dart';

/// 统一处理进入编辑器前的预加载、初始化提示和缓存命中逻辑。
class EditorNavigationHelper {
  static bool _isOpeningDocument = false;

  static Future<void> openEditor(
    BuildContext context,
    String filePath, {
    VoidCallback? onFileOpened,
    String? initialContent,
  }) async {
    appDebugLog('[NAV] openEditor called for: $filePath');
    appDebugLog(
      '[NAV] initialContent provided: ${initialContent != null}, length: ${initialContent?.length ?? "N/A"}',
    );

    if (_isOpeningDocument) {
      appDebugLog('[NAV] Already opening document, returning');
      return;
    }
    _isOpeningDocument = true;

    final overallStopwatch = Stopwatch()..start();

    final fileProvider = context.read<FileProvider>();
    final fileService = fileProvider.fileService;
    final isCached =
        initialContent != null || fileService.isFileCached(filePath);
    appDebugLog('[NAV] isCached: $isCached');
    BuildContext? dialogContext;

    onFileOpened?.call();

    bool dialogShown = false;
    if (!isCached && context.mounted) {
      appDebugLog('[NAV] Showing loading dialog');
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
      appDebugLog('[NAV] Starting file preload...');
      final preloadStopwatch = Stopwatch()..start();

      // Load file content (required)
      final content =
          initialContent ??
          await fileService
              .preloadFile(filePath)
              .timeout(const Duration(seconds: 8));

      preloadStopwatch.stop();
      appDebugLog(
        '[NAV] File preload done in ${preloadStopwatch.elapsedMilliseconds}ms, content length: ${content.length}',
      );

      appDebugLog('[NAV] Starting WebView warmup (non-blocking)...');
      // Warm up WebView in background (optional, don't block on this)
      // Each WebView instance will start its own server if needed
      unawaited(
        warmUpMilkdownWebAssets().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            appDebugLog(
              '[NAV] WebView warmup timed out, will start server on demand',
            );
          },
        ),
      );

      appDebugLog('[NAV] Dismissing dialog and navigating...');
      _dismissDialog(dialogShown, dialogContext, context);
      if (!context.mounted) {
        appDebugLog('[NAV] Context no longer mounted, returning');
        return;
      }

      appDebugLog('[NAV] Pushing EditorScreen...');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EditorScreen(filePath: filePath, initialContent: content),
        ),
      );

      overallStopwatch.stop();
      appDebugLog(
        '[NAV] Navigation complete, total time: ${overallStopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      appDebugLog('[NAV] ERROR: $e');
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
