import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/app_style.dart';
import '../../../../utils/constants.dart';
import '../../../../widgets/webview_markdown_preview.dart';
import '../../../../services/export_service.dart';

class FullscreenPreviewPage extends StatefulWidget {
  final TextEditingController controller;
  final SettingsProvider settings;
  final String fileName;
  final Function(int, bool) onCheckboxChanged;
  final String? filePath;
  final bool autoShareOnOpen;

  const FullscreenPreviewPage({
    super.key,
    required this.controller,
    required this.settings,
    required this.fileName,
    required this.onCheckboxChanged,
    this.filePath,
    this.autoShareOnOpen = false,
  });

  @override
  State<FullscreenPreviewPage> createState() => _FullscreenPreviewPageState();
}

class _FullscreenPreviewPageState extends State<FullscreenPreviewPage> {
  bool _isExporting = false;
  bool _autoSharePending = false;
  final _webViewController = MarkdownWebViewController();
  
  @override
  void initState() {
    super.initState();
    // 监听文本变化以刷新界面
    widget.controller.addListener(_onTextChanged);
    _autoSharePending = widget.autoShareOnOpen;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onPreviewLoaded() {
    if (!_autoSharePending || _isExporting || !mounted) return;
    _autoSharePending = false;
    // Wait one extra frame to ensure WebView content is fully painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shareAsImage();
    });
  }
  
  /// Share the current WebView preview as image (WYSIWYG).
  Future<void> _shareAsImage() async {
    if (_isExporting) return;
    
    setState(() => _isExporting = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('正在生成图片...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
    
    final frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!frameCompleter.isCompleted) frameCompleter.complete();
    });
    await frameCompleter.future;
    
    final fileName = widget.fileName.replaceAll('.md', '').replaceAll('.markdown', '');
    // Prefer an off-screen background WebView capture to avoid visible scrollbars
    // and layout jank in the foreground preview while stitching long screenshots.
    final pngBytes = await _captureInBackgroundWebView() ??
        await _webViewController.captureFullPageScreenshot() ??
        await _webViewController.captureScreenshot();
    final success = pngBytes != null
        ? await ExportService.sharePngBytes(pngBytes, fileName)
        : false;
    
    if (mounted) {
      setState(() => _isExporting = false);
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('图片导出失败'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      // One-tap share flow from file list: close preview automatically only
      // when sharing actually succeeds, so users can retry on failure.
      if (widget.autoShareOnOpen && success) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<Uint8List?> _captureInBackgroundWebView() async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return null;

    final bgController = MarkdownWebViewController();
    final loadCompleter = Completer<void>();
    OverlayEntry? entry;

    try {
      final screenSize = MediaQuery.of(context).size;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      Color bg;
      Color fg;
      if (isDark) {
        final schemes = AppConstants.darkThemeSchemes;
        final idx = widget.settings.darkThemeIndex.clamp(0, schemes.length - 1);
        bg = schemes[idx].background;
        fg = schemes[idx].text;
      } else {
        final schemes = AppConstants.lightThemeSchemes;
        final idx = widget.settings.lightThemeIndex.clamp(0, schemes.length - 1);
        bg = schemes[idx].background;
        fg = schemes[idx].text;
      }

      // Use the same inner preview width (page width minus horizontal margins).
      final captureWidth =
          (screenSize.width - 32).clamp(320.0, screenSize.width).toDouble();

      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -10000,
          top: 0,
          width: captureWidth,
          height: screenSize.height,
          child: Material(
            color: bg,
            child: WebViewMarkdownPreview(
              data: widget.controller.text,
              isDark: isDark,
              fontSize: widget.settings.fontSize,
              fontFamily: widget.settings.editorFontFamily == 'System'
                  ? null
                  : widget.settings.editorFontFamily,
              bgColor: bg,
              fgColor: fg,
              codeFont: widget.settings.codeFontFamily == 'System'
                  ? null
                  : widget.settings.codeFontFamily,
              onCheckboxChanged: (_, __) {},
              hidePageScrollbar: true,
              onLoadFinished: () {
                if (!loadCompleter.isCompleted) loadCompleter.complete();
              },
              controller: bgController,
              baseDirectory:
                  widget.filePath != null ? File(widget.filePath!).parent.path : null,
            ),
          ),
        ),
      );

      overlay.insert(entry);
      await loadCompleter.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      await Future.delayed(const Duration(milliseconds: 120));

      return await bgController.captureFullPageScreenshot() ??
          await bgController.captureScreenshot();
    } catch (_) {
      return null;
    } finally {
      entry?.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: appStyle.scaledSurfaceColor(
                Theme.of(context).colorScheme,
                alpha: 0.8,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        actions: [
          // 分享为图片按钮
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: _isExporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.share,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
            tooltip: '分享为图片',
            onPressed: _isExporting ? null : _shareAsImage,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            Color bg;
            Color fg;
            if (isDark) {
              final schemes = AppConstants.darkThemeSchemes;
              final idx = widget.settings.darkThemeIndex.clamp(0, schemes.length - 1);
              bg = schemes[idx].background;
              fg = schemes[idx].text;
            } else {
              final schemes = AppConstants.lightThemeSchemes;
              final idx = widget.settings.lightThemeIndex.clamp(0, schemes.length - 1);
              bg = schemes[idx].background;
              fg = schemes[idx].text;
            }
            return WebViewMarkdownPreview(
              data: widget.controller.text,
              isDark: isDark,
              fontSize: widget.settings.fontSize,
              fontFamily: widget.settings.editorFontFamily == 'System'
                  ? null
                  : widget.settings.editorFontFamily,
              bgColor: bg,
              fgColor: fg,
              codeFont: widget.settings.codeFontFamily == 'System'
                  ? null
                  : widget.settings.codeFontFamily,
              onCheckboxChanged: widget.onCheckboxChanged,
              hidePageScrollbar: true,
              onLoadFinished: _onPreviewLoaded,
              controller: _webViewController,
              baseDirectory:
                  widget.filePath != null ? File(widget.filePath!).parent.path : null,
            );
          }),
        ),
      ),
    );
  }
}
