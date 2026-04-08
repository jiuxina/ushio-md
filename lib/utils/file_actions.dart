import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../services/share_service.dart';
import '../services/export_service.dart';
import '../services/file_service.dart';
import '../screens/folder_browser_screen.dart';
import '../utils/constants.dart';
import '../widgets/milkdown_webview_editor.dart';
import 'editor_navigation_helper.dart';

enum FileSource { myFiles, pinned, history }

/// 防抖管理器
class _Debouncer {
  static final Map<String, bool> _operations = {};

  /// 检查并标记操作是否正在进行
  static bool startOperation(String key) {
    if (_operations[key] == true) return false;
    _operations[key] = true;
    return true;
  }

  /// 完成操作
  static void endOperation(String key) {
    _operations[key] = false;
  }

  /// 执行防抖操作
  static Future<T?> run<T>(String key, Future<T> Function() operation) async {
    if (!startOperation(key)) return null;
    try {
      return await operation();
    } finally {
      endOperation(key);
    }
  }
}

class FileActions {
  static void showFileContextMenu(
    BuildContext context,
    String path,
    FileProvider fileProvider, {
    bool isRecent = false,
    bool isPinned = false,
    VoidCallback? onRefresh,
    FileSource? source,
  }) {
    final shareService = ShareService();
    final fileName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFilePinned(path);
    // Use source if provided, otherwise infer from bools (for backward compatibility if any)
    final effectiveSource =
        source ??
        (isPinned
            ? FileSource.pinned
            : (isRecent ? FileSource.history : FileSource.myFiles));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fileName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            _buildPathPreview(context, path),
            const SizedBox(height: 20),

            // 1. Share (With submenu for file share options)
            _buildShareSubmenu(context, path, shareService),
            const SizedBox(height: 8),

            // 2. Rename (All sources)
            _buildContextMenuItem(
              context,
              icon: Icons.edit,
              label: '重命名',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                showRenameDialog(
                  context,
                  path,
                  fileProvider,
                  onRefresh: onRefresh,
                );
              },
            ),
            const SizedBox(height: 8),

            // 3. Pin/Unpin (All sources - Logic varies slightly)
            // Pinned: Cancel Top (Unpin)
            // Others: Pin/Unpin Toggle
            _buildContextMenuItem(
              context,
              icon: isCurrentlyPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                // 防抖：避免快速点击
                _Debouncer.run('pin_$path', () async {
                  fileProvider.togglePinFile(path);
                  return null;
                });
              },
            ),
            const SizedBox(height: 8),

            // 4. Delete / Remove (Source dependent)
            if (effectiveSource == FileSource.myFiles)
              _buildContextMenuItem(
                context,
                icon: Icons.delete,
                label: '删除文件',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  confirmDelete(
                    context,
                    path,
                    fileProvider,
                    onRefresh: onRefresh,
                  );
                },
              ),

            if (effectiveSource == FileSource.history)
              _buildContextMenuItem(
                context,
                icon: Icons.history, // Icon for remove from history
                label: '移除记录',
                color: Colors
                    .red, // Or orange/grey? Red implies destructive usually.
                onTap: () {
                  Navigator.pop(context);
                  fileProvider.removeFromRecentFiles(path);
                },
              ),

            // Pinned: No delete/remove option requested
            // So we add nothing else for pinned.
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static void showFolderContextMenu(
    BuildContext context,
    String path,
    FileProvider fileProvider, {
    bool isPinned = false,
    FileSource? source,
    VoidCallback? onRefresh,
  }) {
    // folders usually don't support simple share unless zipped.
    // Assuming we might want to implement zip share later or share path string.
    // For now, adding the visual option as requested.
    final shareService = ShareService();
    final folderName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFolderPinned(path);
    final effectiveSource =
        source ?? (isPinned ? FileSource.pinned : FileSource.myFiles);
    // Note: Folder browser history (?) - history tab has folders? Yes "Recent Folders".
    // So if it's from history tab, source is history.

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              folderName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            _buildPathPreview(context, path),
            const SizedBox(height: 20),

            // 1. Share folder as ZIP
            _buildContextMenuItem(
              context,
              icon: Icons.folder_zip,
              label: '分享文件夹 (ZIP)',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                final success = await shareService.shareFolder(path);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 12),
                          Text('压缩分享失败'),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),

            // 2. Rename (All sources)
            _buildContextMenuItem(
              context,
              icon: Icons.edit,
              label: '重命名',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                showRenameFolderDialog(
                  context,
                  path,
                  fileProvider,
                  onRefresh: onRefresh,
                );
              },
            ),
            const SizedBox(height: 8),

            // 3. Pin/Unpin (All sources)
            _buildContextMenuItem(
              context,
              icon: isCurrentlyPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                fileProvider.togglePinFolder(path);
              },
            ),
            const SizedBox(height: 8),

            // 4. Delete / Remove (Source dependent)
            if (effectiveSource == FileSource.myFiles)
              _buildContextMenuItem(
                context,
                icon: Icons.delete,
                label: '删除文件夹',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  confirmDeleteFolder(
                    context,
                    path,
                    fileProvider,
                    onRefresh: onRefresh,
                  );
                },
              ),

            if (effectiveSource == FileSource.history)
              _buildContextMenuItem(
                context,
                icon: Icons.history,
                label: '移除记录',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  fileProvider.removeFromRecentFolders(path);
                },
              ),

            // Pinned folders: No delete option requested.
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Widget _buildContextMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildPathPreview(BuildContext context, String path) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        path,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          height: 1.35,
        ),
        textAlign: TextAlign.center,
        softWrap: true,
      ),
    );
  }

  /// 构建文件分享子菜单
  ///
  /// 提供三种分享选项：
  /// - 以文件分享：直接分享 .md 文件
  /// - 以图片分享：后台使用 Milkdown 渲染并生成长图后分享
  /// - 以 PDF 分享：转换为 PDF 后分享
  static Widget _buildShareSubmenu(
    BuildContext context,
    String path,
    ShareService shareService,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.share, color: Colors.blue),
          title: const Text(
            '分享',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 12,
          ),
          children: [
            // 以文件分享
            _buildShareOption(
              context,
              icon: Icons.insert_drive_file,
              label: '以文件分享',
              subtitle: '分享 .md 原文件',
              onTap: () {
                Navigator.pop(context);
                shareService.shareFile(path);
              },
            ),
            const SizedBox(height: 8),
            // 以图片分享
            _buildShareOption(
              context,
              icon: Icons.image,
              label: '以图片分享',
              subtitle: '后台渲染并合成长图分享',
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _shareAsImageDirectly(context, path);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('图片分享失败: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            // 以 PDF 分享
            _buildShareOption(
              context,
              icon: Icons.picture_as_pdf,
              label: '以 PDF 分享',
              subtitle: '转换为 PDF 后分享',
              onTap: () async {
                Navigator.pop(context);

                // 防抖检查
                final debounceKey = 'pdf_share_$path';
                if (!_Debouncer.startOperation(debounceKey)) return;

                // 读取文件内容
                try {
                  final file = File(path);
                  final stat = await file.stat();

                  // 检查文件大小
                  if (FileService.isFileTooLarge(stat.size)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '文件过大 (${FileService.formatFileSize(stat.size)})，'
                                  '最大支持 ${FileService.formatFileSize(FileService.maxFileSize)}',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                    _Debouncer.endOperation(debounceKey);
                    return;
                  }

                  final content = await file.readAsString();
                  final fileName = path
                      .split(Platform.pathSeparator)
                      .last
                      .replaceAll('.md', '')
                      .replaceAll('.markdown', '');

                  // 显示加载提示
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('正在生成 PDF...'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }

                  final success = await ExportService.exportAndShareAsPdf(
                    content,
                    fileName,
                    title: fileName,
                  );

                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 12),
                            Text('PDF 导出失败'),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } finally {
                  _Debouncer.endOperation(debounceKey);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showImageShareProgress(
    ScaffoldMessengerState messenger,
    ThemeData theme, {
    required String status,
    required double progress,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(days: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.24),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static Widget? _buildEditorBackgroundLayer(SettingsProvider settings) {
    final path = settings.editorBackgroundImagePath;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;

    Widget imageLayer = Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    final brightness = settings.editorBackgroundBrightness;
    if ((brightness - 1.0).abs() > 0.001) {
      imageLayer = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: imageLayer,
      );
    }

    if (settings.editorBackgroundBlurEnabled) {
      imageLayer = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: settings.editorBackgroundBlur,
          sigmaY: settings.editorBackgroundBlur,
        ),
        child: imageLayer,
      );
    }

    return imageLayer;
  }

  static Future<void> _shareAsImageDirectly(
    BuildContext context,
    String path,
  ) async {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final themeData = Theme.of(context);
    final surfaceColor = themeData.colorScheme.surface;
    final mediaSize = MediaQuery.of(context).size;
    final overlay = Overlay.maybeOf(context);
    final settings = context.read<SettingsProvider>();
    final bgColor = _resolveShareBackgroundColor(
      themeData.brightness,
      settings,
    );

    if (overlay == null) {
      throw Exception('无法获取 Overlay，无法生成图片');
    }

    final fileName = path
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.md', '')
        .replaceAll('.markdown', '');
    final markdown = await File(path).readAsString();

    _showImageShareProgress(
      scaffoldMessenger,
      themeData,
      status: '初始化后台渲染...',
      progress: 0.08,
    );

    final controller = MilkdownWebViewController();
    final loadCompleter = Completer<void>();
    OverlayEntry? entry;

    try {
      final captureWidth = (mediaSize.width - 32)
          .clamp(320.0, mediaSize.width)
          .toDouble();

      _showImageShareProgress(
        scaffoldMessenger,
        themeData,
        status: '后台 Milkdown 渲染中...',
        progress: 0.28,
      );

      entry = OverlayEntry(
        builder: (_) {
          final bgLayer = _buildEditorBackgroundLayer(settings);
          return Positioned(
            left: -10000,
            top: 0,
            width: captureWidth,
            height: mediaSize.height,
            child: Theme(
              data: themeData,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bgLayer != null) bgLayer,
                    Container(
                      color: bgLayer == null
                          ? surfaceColor
                          : Colors.transparent,
                      child: MilkdownWebViewEditor(
                        initialMarkdown: markdown,
                        readOnly: true,
                        fontSize: settings.fontSize,
                        bodyFont: settings.editorFontFamily == 'System'
                            ? null
                            : settings.editorFontFamily,
                        monoFont: settings.codeFontFamily == 'System'
                            ? null
                            : settings.codeFontFamily,
                        onLoadFinished: () {
                          if (!loadCompleter.isCompleted) {
                            loadCompleter.complete();
                          }
                        },
                        controller: controller,
                        baseDirectory: File(path).parent.path,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(entry);
      await loadCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));

      _showImageShareProgress(
        scaffoldMessenger,
        themeData,
        status: '正在合成长图...',
        progress: 0.72,
      );

      final png = await controller.captureFullPageScreenshot();
      if (png == null) {
        throw Exception('长图生成失败');
      }

      _showImageShareProgress(
        scaffoldMessenger,
        themeData,
        status: '应用主题背景...',
        progress: 0.82,
      );

      final normalizedPng =
          await _applyBackgroundColorToPng(png, bgColor) ?? png;

      _showImageShareProgress(
        scaffoldMessenger,
        themeData,
        status: '调用系统分享...',
        progress: 0.9,
      );

      final success = await ExportService.sharePngBytes(
        normalizedPng,
        fileName,
      );
      if (!success) {
        throw Exception('图片分享失败');
      }

      _showImageShareProgress(
        scaffoldMessenger,
        themeData,
        status: '分享完成',
        progress: 1.0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 220));
    } finally {
      entry?.remove();
      scaffoldMessenger.hideCurrentSnackBar();
    }
  }

  static Color _resolveShareBackgroundColor(
    Brightness brightness,
    SettingsProvider settings,
  ) {
    if (brightness == Brightness.dark) {
      final schemes = AppConstants.darkThemeSchemes;
      final index = settings.darkThemeIndex.clamp(0, schemes.length - 1);
      return schemes[index].background;
    }
    final schemes = AppConstants.lightThemeSchemes;
    final index = settings.lightThemeIndex.clamp(0, schemes.length - 1);
    return schemes[index].background;
  }

  static Future<Uint8List?> _applyBackgroundColorToPng(
    Uint8List pngBytes,
    Color background,
  ) async {
    try {
      final codec = await instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = background;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        paint,
      );
      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final flattened = await picture.toImage(image.width, image.height);
      final data = await flattened.toByteData(format: ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 构建分享选项
  static Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final color = isDisabled ? Colors.grey : Colors.blue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDisabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '待开发',
                    style: TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showRenameDialog(
    BuildContext context,
    String path,
    FileProvider fileProvider, {
    VoidCallback? onRefresh,
  }) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName
        .replaceAll('.md', '')
        .replaceAll('.markdown', '');
    final controller = TextEditingController(text: nameWithoutExt);

    // 非法字符正则（文件名不能包含以下字符）
    final illegalCharsRegex = RegExp(r'[\\/:*?"<>|]');
    String? errorText;

    // 防抖标志
    bool isRenaming = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('重命名文件'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 250, // 限制长度，留 5 字符给 .md
                  decoration: InputDecoration(
                    labelText: '新文件名',
                    suffixText: '.md',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: errorText,
                    counterText: '', // 隐藏计数器文字
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorText = '文件名不能为空';
                      } else if (illegalCharsRegex.hasMatch(value)) {
                        errorText = '文件名不能包含 \\ / : * ? " < > |';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: errorText == null && controller.text.isNotEmpty
                    ? () => Navigator.pop(context, controller.text)
                    : null,
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null &&
        result.isNotEmpty &&
        result != nameWithoutExt &&
        !isRenaming) {
      isRenaming = true;

      // 使用 FileService 验证文件名
      final sanitizedName = FileService.sanitizeFileName(
        result,
        defaultName: nameWithoutExt,
      );

      try {
        final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
        final newPath = '$dir${Platform.pathSeparator}$sanitizedName';

        // 检查目标文件是否已存在
        if (File(newPath).existsSync() && newPath != path) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('文件名已存在')));
          }
          controller.dispose();
          return;
        }

        final file = File(path);
        await file.rename(newPath);
        fileProvider.refresh();
        onRefresh?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    }

    controller.dispose();
  }

  static Future<void> confirmDelete(
    BuildContext context,
    String path,
    FileProvider fileProvider, {
    VoidCallback? onRefresh,
  }) async {
    final fileName = path.split(Platform.pathSeparator).last;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除文件'),
        content: Text('确定要删除 "$fileName" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await fileProvider.deleteFile(path);
      onRefresh?.call();
    }
  }

  static Future<void> showCreateFileInFolderDialog(
    BuildContext context,
    String folderPath,
    FileProvider fileProvider, {
    VoidCallback? onRefresh,
  }) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('新建文件'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '文件名',
            suffixText: '.md',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final file = await fileProvider.createFile(folderPath, result);
      if (file != null && context.mounted) {
        await EditorNavigationHelper.openEditor(
          context,
          file.path,
          initialContent: file.content,
        );
        // Trigger refresh after returning from editor
        onRefresh?.call();
      }
    }
  }

  static Future<void> showCreateFileDialog(
    BuildContext context,
    FileProvider fileProvider,
  ) async {
    final nameController = TextEditingController();
    final settings = context.read<SettingsProvider>();

    // Determine default path priority:
    // 1. Current directory (if explicitly set/known preference in dialog context? No, usually derived)
    // 2. User defined default directory
    // 3. First recent folder
    // Note: fileProvider.currentDirectory might be null if we are at root or not browsing.
    String? selectedPath = fileProvider.currentDirectory;

    if (selectedPath == null) {
      if (settings.defaultDirectory != null &&
          Directory(settings.defaultDirectory!).existsSync()) {
        selectedPath = settings.defaultDirectory;
      } else if (fileProvider.recentFolders.isNotEmpty) {
        selectedPath = fileProvider.recentFolders.first;
      }
    }

    // If still null, try to use root path?
    // fileProvider doesn't track root path visibly here, but the dialog allows picking.

    if (selectedPath == null && fileProvider.recentFolders.isNotEmpty) {
      selectedPath = fileProvider.recentFolders.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('新建 Markdown'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '文件名',
                    hintText: '例如: 我的笔记',
                    suffixText: '.md',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '保存位置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final path = await fileProvider.fileService.pickDirectory();
                    if (path != null) {
                      setDialogState(() => selectedPath = path);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPath ?? '点击选择文件夹',
                            style: TextStyle(
                              color: selectedPath != null
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: selectedPath == null || nameController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'name': nameController.text,
                        'path': selectedPath!,
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final file = await fileProvider.createFile(
        result['path']!,
        result['name']!,
      );
      if (file != null && context.mounted) {
        await EditorNavigationHelper.openEditor(
          context,
          file.path,
          initialContent: file.content,
        );
      }
    }
  }

  static Future<void> showCreateFolderDialog(
    BuildContext context,
    FileProvider fileProvider,
  ) async {
    final nameController = TextEditingController();
    final settings = context.read<SettingsProvider>();

    String? selectedPath = fileProvider.currentDirectory;

    if (selectedPath == null) {
      if (settings.defaultDirectory != null &&
          Directory(settings.defaultDirectory!).existsSync()) {
        selectedPath = settings.defaultDirectory;
      } else if (fileProvider.recentFolders.isNotEmpty) {
        selectedPath = fileProvider.recentFolders.first;
      }
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.create_new_folder,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              const Text('新建文件夹'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '文件夹名称',
                    hintText: '例如: 我的笔记',
                    prefixIcon: const Icon(Icons.folder),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '创建位置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final path = await fileProvider.fileService.pickDirectory();
                    if (path != null) {
                      setDialogState(() => selectedPath = path);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPath ?? '点击选择位置',
                            style: TextStyle(
                              color: selectedPath != null
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: selectedPath == null || nameController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'name': nameController.text,
                        'path': selectedPath!,
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final newFolderPath =
            '${result['path']}${Platform.pathSeparator}${result['name']}';
        await Directory(newFolderPath).create(recursive: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件夹 "${result['name']}" 创建成功')),
          );
          // Navigate to the new folder
          await fileProvider.addToRecentFolders(newFolderPath);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FolderBrowserScreen(folderPath: newFolderPath),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
        }
      }
    }
  }

  static Future<void> showRenameFolderDialog(
    BuildContext context,
    String path,
    FileProvider fileProvider, {
    VoidCallback? onRefresh,
  }) async {
    final folderName = path.split(Platform.pathSeparator).last;
    final controller = TextEditingController(text: folderName);

    // 非法字符正则（文件夹名不能包含以下字符）
    final illegalCharsRegex = RegExp(r'[\\/:*?"<>|]');
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('重命名文件夹'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '新文件夹名',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: errorText,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorText = '文件夹名不能为空';
                      } else if (illegalCharsRegex.hasMatch(value)) {
                        errorText = '文件夹名不能包含 \\ / : * ? " < > |';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: errorText == null && controller.text.isNotEmpty
                    ? () => Navigator.pop(context, controller.text)
                    : null,
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty && result != folderName) {
      try {
        final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
        final newPath = '$dir${Platform.pathSeparator}$result';
        final directory = Directory(path);
        await directory.rename(newPath);
        fileProvider.refresh();
        onRefresh?.call();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    }
  }

  static Future<void> confirmDeleteFolder(
    BuildContext context,
    String path,
    FileProvider fileProvider, {
    VoidCallback? onRefresh,
  }) async {
    final folderName = path.split(Platform.pathSeparator).last;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除文件夹'),
        content: Text('确定要删除 "$folderName" 及其所有内容吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await fileProvider.deleteFolder(path);
      onRefresh?.call();
    }
  }
}
