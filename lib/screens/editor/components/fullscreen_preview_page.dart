import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../widgets/markdown_preview.dart';
import '../../../../widgets/app_background.dart';
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
  final GlobalKey _previewKey = GlobalKey();
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
        duration: const Duration(seconds: 2),
      ),
    );
    
    final fileName = widget.fileName.replaceAll('.md', '').replaceAll('.markdown', '');
    final success = await ExportService.captureAndShareAsImage(_previewKey, fileName);
    
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
      body: RepaintBoundary(
        key: _previewKey,
        child: AppBackground(
          child: MarkdownPreview(
            data: widget.controller.text,
            settings: widget.settings,
            onCheckboxChanged: widget.onCheckboxChanged,
            baseDirectory: widget.filePath != null ? File(widget.filePath!).parent.path : null,
          ),
        ),
      ),
    );
  }
}

