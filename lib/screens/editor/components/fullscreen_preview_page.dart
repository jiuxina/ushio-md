import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/constants.dart';
import '../../../../widgets/markdown_preview.dart';
import '../../../../widgets/webview_markdown_preview.dart';
import '../../../../services/export_service.dart';

class FullscreenPreviewPage extends StatefulWidget {
  final TextEditingController controller;
  final SettingsProvider settings;
  final String fileName;
  final Function(int, bool) onCheckboxChanged;
  final String? filePath;

  const FullscreenPreviewPage({
    super.key,
    required this.controller,
    required this.settings,
    required this.fileName,
    required this.onCheckboxChanged,
    this.filePath,
  });

  @override
  State<FullscreenPreviewPage> createState() => _FullscreenPreviewPageState();
}

class _FullscreenPreviewPageState extends State<FullscreenPreviewPage> {
  bool _isExporting = false;
  
  @override
  void initState() {
    super.initState();
    // 监听文本变化以刷新界面
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }
  
  /// Share the full document content as a long image.
  ///
  /// Renders the entire markdown content off-screen using an [OverlayEntry] so
  /// the image is not clipped to the current viewport height.
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
    
    final screenWidth = MediaQuery.of(context).size.width;
    final captureKey = GlobalKey();
    final baseDir = widget.filePath != null ? File(widget.filePath!).parent.path : null;
    // Snapshot settings to avoid using context inside the overlay builder
    final settings = widget.settings;
    final markdownData = widget.controller.text;
    final surface = Theme.of(context).colorScheme.surface;

    // Insert a full-height (unconstrained) markdown render into the overlay.
    // Positioned off-screen to the left so it is rendered but not visible.
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -screenWidth,
        top: 0,
        width: screenWidth,
        child: Material(
          color: surface,
          child: RepaintBoundary(
            key: captureKey,
            child: Container(
              color: surface,
              padding: const EdgeInsets.all(16),
              child: MarkdownPreview(
                data: markdownData,
                settings: settings,
                shrinkWrap: true,
                onCheckboxChanged: (_, __) {},
                baseDirectory: baseDir,
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(overlayEntry);
    
    // Wait for the overlay widget to be fully laid out and painted.
    // Use addPostFrameCallback with a Completer to reliably wait for the next frame.
    final frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!frameCompleter.isCompleted) frameCompleter.complete();
    });
    await frameCompleter.future;
    
    final fileName = widget.fileName.replaceAll('.md', '').replaceAll('.markdown', '');
    final success = await ExportService.captureAndShareAsImage(captureKey, fileName);
    
    overlayEntry.remove();
    
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
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
            Color bg, fg;
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
              baseDirectory:
                  widget.filePath != null ? File(widget.filePath!).parent.path : null,
            );
          }),
        ),
      ),
    );
  }
}

