import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import '../models/milkdown_bridge.dart';
import '../services/my_files_service.dart';

typedef MilkdownBridgeMessageHandler = void Function(Map<String, dynamic> msg);
typedef MilkdownCheckboxToggleHandler = void Function(int index, bool value);

const _defaultBodyFont = 'Noto Sans SC';
const _defaultMonoFont = 'JetBrains Mono';
const _defaultFontSize = 16.0;
const _defaultLineHeight = 1.6;

Future<void> warmUpMilkdownWebAssets() async {}

class MilkdownWebViewController {
  _MilkdownWebViewEditorState? _state;
  InAppWebViewController? _webViewController;

  void _attach(_MilkdownWebViewEditorState state) {
    _state = state;
  }

  void _detach(_MilkdownWebViewEditorState state) {
    if (identical(_state, state)) {
      _state = null;
      _webViewController = null;
    }
  }

  void _attachWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void suppressNextReload() {
    _state?._suppressNextReload = true;
  }

  Future<void> setMarkdown(String markdown) async {
    await _state?._sendInitDoc(markdownOverride: markdown);
  }

  Future<void> updateTheme(ThemePalettePayload payload) async {
    await _state?._sendTheme(payloadOverride: payload);
  }

  Future<void> execCmd(String cmd, {Map<String, dynamic>? args}) async {
    await _state?._sendExecCmd(cmd, args: args);
  }

  Future<void> undo() => execCmd('undo');
  Future<void> redo() => execCmd('redo');
  Future<void> toggleBold() => execCmd('toggle_bold');
  Future<void> toggleItalic() => execCmd('toggle_italic');
  Future<void> insertTable() => execCmd('insert_table');
  Future<void> insertHorizontalRule() => execCmd('insert_hr');
  Future<void> focusEditor() => execCmd('focus_editor');
  Future<void> toggleStrikethrough() => execCmd('toggle_strikethrough');
  Future<void> toggleHighlight() => execCmd('toggle_highlight');
  Future<void> toggleInlineCode() => execCmd('toggle_inline_code');
  Future<void> setHeading(int level) => execCmd('set_heading', args: {'level': level});
  Future<void> toggleBlockquote() => execCmd('toggle_blockquote');
  Future<void> toggleBulletList() => execCmd('toggle_bullet_list');
  Future<void> toggleOrderedList() => execCmd('toggle_ordered_list');
  Future<void> insertCodeBlock({String? language}) =>
      execCmd('insert_code_block', args: {
        if (language != null) 'language': language,
      });
  Future<void> insertMathBlock() => execCmd('insert_math_block');
  Future<void> toggleLink({String href = 'https://', String? title}) =>
      execCmd('toggle_link', args: {
        'href': href,
        if (title != null) 'title': title,
      });
  Future<void> goToNextTableCell() => execCmd('table_next_cell');
  Future<void> goToPrevTableCell() => execCmd('table_prev_cell');
  Future<void> addTableRowBefore() => execCmd('table_add_row_before');
  Future<void> addTableRowAfter() => execCmd('table_add_row_after');
  Future<void> addTableColumnBefore() => execCmd('table_add_col_before');
  Future<void> addTableColumnAfter() => execCmd('table_add_col_after');
  Future<void> deleteSelectedTableCells() => execCmd('table_delete_selected');
  Future<void> deleteCurrentTableRow() => execCmd('table_delete_row');
  Future<void> deleteCurrentTableColumn() => execCmd('table_delete_col');
  Future<void> insertImage({required String src, String? alt}) =>
      execCmd('insert_image', args: {
        'src': src,
        if (alt != null) 'alt': alt,
      });
  Future<void> insertEmoji({String emoji = '😀'}) =>
      execCmd('insert_emoji', args: {'emoji': emoji});

  Future<void> scrollToHeading({
    required int headingIndex,
    required int lineNumber,
    required String headingText,
    double topOffset = 32.0,
  }) async {
    await execCmd('toc_jump', args: {
      'headingIndex': headingIndex,
      'lineNumber': lineNumber,
      'headingText': headingText,
      'topOffset': topOffset,
    });
  }

  Future<Uint8List?> captureScreenshot() async {
    try {
      return await _webViewController?.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> captureFullPageScreenshot({
    int maxShots = 30,
    Duration settleDelay = const Duration(milliseconds: 80),
  }) async {
    final c = _webViewController;
    if (c == null) return null;

    try {
      final originalYRaw = await c.evaluateJavascript(source: 'window.scrollY || 0');
      final vhRaw = await c.evaluateJavascript(source: 'window.innerHeight || 0');
      final shRaw = await c.evaluateJavascript(
        source: 'Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) || 0',
      );

      final originalY =
          (double.tryParse(originalYRaw?.toString() ?? '0') ?? 0.0).clamp(0.0, double.infinity);
      final viewportHeightCss =
          (double.tryParse(vhRaw?.toString() ?? '0') ?? 0.0).clamp(1.0, double.infinity);
      final pageHeightCss =
          (double.tryParse(shRaw?.toString() ?? '0') ?? 0.0).clamp(1.0, double.infinity);

      final steps = <double>[];
      for (double y = 0; y < pageHeightCss; y += viewportHeightCss) {
        steps.add(y);
        if (steps.length >= maxShots) break;
      }

      final captures = <({double yCss, Uint8List png})>[];
      for (final y in steps) {
        await c.evaluateJavascript(source: 'window.scrollTo(0, $y)');
        await Future.delayed(settleDelay);
        final png = await c.takeScreenshot();
        if (png == null) continue;
        captures.add((yCss: y, png: png));
      }

      await c.evaluateJavascript(source: 'window.scrollTo(0, $originalY)');

      if (captures.isEmpty) return null;

      final first = await _decodePng(captures.first.png);
      final scale = first.height / viewportHeightCss;
      final targetWidth = first.width;
      final targetHeight = (pageHeightCss * scale).ceil();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      for (final cap in captures) {
        final img = await _decodePng(cap.png);
        final dy = (cap.yCss * scale).roundToDouble();
        canvas.drawImage(img, ui.Offset(0, dy), ui.Paint());
      }

      final picture = recorder.endRecording();
      final stitched = await picture.toImage(targetWidth, targetHeight);
      final bytes = await stitched.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _decodePng(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class MilkdownWebViewEditor extends StatefulWidget {
  final String initialMarkdown;
  final bool readOnly;
  final ValueChanged<String>? onContentChange;
  final MilkdownBridgeMessageHandler? onBridgeMessage;
  final ValueChanged<OnImageErrorPayload>? onImageError;
  final ValueChanged<OnOutlineUpdatePayload>? onOutlineUpdate;
  final ValueChanged<OnLinkClickPayload>? onLinkClick;
  final MilkdownCheckboxToggleHandler? onCheckboxToggle;
  final ValueChanged<OnUploadImagesRequestPayload>? onUploadImagesRequest;
  final bool enableInsertImagePicker;
  final bool enableInsertImageUrl;
  final VoidCallback? onLoadFinished;
  final MilkdownWebViewController? controller;
  final String? bodyFont;
  final String? monoFont;
  final double? fontSize;
  final double? lineHeight;
  final String? baseDirectory;

  const MilkdownWebViewEditor({
    super.key,
    required this.initialMarkdown,
    this.readOnly = false,
    this.onContentChange,
    this.onBridgeMessage,
    this.onImageError,
    this.onOutlineUpdate,
    this.onLinkClick,
    this.onCheckboxToggle,
    this.onUploadImagesRequest,
    this.enableInsertImagePicker = true,
    this.enableInsertImageUrl = true,
    this.onLoadFinished,
    this.controller,
    this.bodyFont,
    this.monoFont,
    this.fontSize,
    this.lineHeight,
    this.baseDirectory,
  });

  @override
  State<MilkdownWebViewEditor> createState() => _MilkdownWebViewEditorState();
}

class _MilkdownWebViewEditorState extends State<MilkdownWebViewEditor> {
  static const _documentRoot = 'assets/milkdown_web';
  static const int _maxUploadPersistRetries = 2;
  static const String _localFileScheme = 'ushio-local-file';

  InAppWebViewController? _controller;
  InAppLocalhostServer? _localhostServer;
  String? _initialUrl;
  String? _lastThemeSignature;
  String? _lastSyncedMarkdown;
  bool _isServerStarting = false;
  bool _didFinishFirstRender = false;
  bool _suppressNextReload = false;

  Future<CustomSchemeResponse?> _serveLocalFileRequest(Uri uri) async {
    if (uri.scheme != _localFileScheme) return null;
    final requestedPathRaw = uri.queryParameters['path'] ?? '';
    if (requestedPathRaw.isEmpty) {
      return CustomSchemeResponse(
        data: Uint8List(0),
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
      );
    }
    final requestedPath = requestedPathRaw.trim();
    final file = File(requestedPath);
    if (!await file.exists()) {
      return CustomSchemeResponse(
        data: Uint8List(0),
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
      );
    }
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(requestedPath) ?? 'application/octet-stream';
    return CustomSchemeResponse(
      data: bytes,
      contentType: mime,
      contentEncoding: 'binary',
    );
  }

  @override
  void initState() {
    super.initState();
    _lastSyncedMarkdown = widget.initialMarkdown;
    _startLocalhostServer();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
  }

  Future<void> _startLocalhostServer() async {
    if (_isServerStarting || _localhostServer != null) return;
    _isServerStarting = true;
    try {
      final server = InAppLocalhostServer(documentRoot: _documentRoot);
      await server.start();
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() {
        _localhostServer = server;
        _initialUrl = 'http://localhost:${server.port}/index.html';
      });
    } catch (e) {
      debugPrint('Failed to start Milkdown localhost server: $e');
      if (!mounted) return;
      setState(() {
        _initialUrl = '';
      });
    } finally {
      _isServerStarting = false;
    }
  }

  ThemePalettePayload _buildThemePayload() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    final bodyFont = widget.bodyFont ?? _defaultBodyFont;
    final monoFont = widget.monoFont ?? _defaultMonoFont;
    final fontSize = widget.fontSize ?? _defaultFontSize;
    final lineHeight = widget.lineHeight ?? _defaultLineHeight;
    return ThemePalettePayload(
      mode: mode,
      colors: {
        'primary': _toCssHex(colorScheme.primary),
        'onPrimary': _toCssHex(colorScheme.onPrimary),
        'secondary': _toCssHex(colorScheme.secondary),
        'onSecondary': _toCssHex(colorScheme.onSecondary),
        'surface': _toCssHex(colorScheme.surface),
        'onSurface': _toCssHex(colorScheme.onSurface),
        'background': _toCssHex(colorScheme.surface),
        'onBackground': _toCssHex(colorScheme.onSurface),
        'error': _toCssHex(colorScheme.error),
        'onError': _toCssHex(colorScheme.onError),
        'outline': _toCssHex(colorScheme.outline),
        'shadow': _toCssRgba(colorScheme.shadow),
      },
      bodyFont: bodyFont,
      monoFont: monoFont,
      sizePx: fontSize,
      lineHeight: lineHeight,
    );
  }

  String _themeSignature() {
    final payload = _buildThemePayload();
    return jsonEncode(payload.toJson());
  }

  void _syncThemeIfNeeded() {
    if (_controller == null) return;
    final sig = _themeSignature();
    if (_lastThemeSignature != sig) {
      _sendTheme();
    }
  }

  Future<void> _sendInitDoc({String? markdownOverride}) async {
    final markdown = markdownOverride ?? widget.initialMarkdown;
    _lastSyncedMarkdown = markdown;
    final msg = BridgeEnvelope<InitDocPayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'init_doc',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: InitDocPayload(
        markdown: markdown,
        baseDirectory: widget.baseDirectory,
        readOnly: widget.readOnly,
      ),
    );
    await _sendMessage(msg.toJson((payload) => payload.toJson()));
  }

  Future<void> _sendTheme({ThemePalettePayload? payloadOverride}) async {
    final payload = payloadOverride ?? _buildThemePayload();
    _lastThemeSignature = jsonEncode(payload.toJson());
    final msg = BridgeEnvelope<ThemePalettePayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'update_theme',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );
    await _sendMessage(msg.toJson((p) => p.toJson()));
  }

  Future<void> _sendExecCmd(String cmd, {Map<String, dynamic>? args}) async {
    final msg = BridgeEnvelope<ExecCmdPayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'exec_cmd',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: ExecCmdPayload(cmd: cmd, args: args),
    );
    await _sendMessage(msg.toJson((p) => p.toJson()));
  }

  Future<void> _sendUploadImagesResult(
    String requestId, {
    required List<Map<String, dynamic>> images,
    String? reason,
    String? failureReason,
    int? failureCount,
  }) async {
    await _sendExecCmd(
      'upload_images_result',
      args: {
        'requestId': requestId,
        'images': images,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (failureReason != null && failureReason.isNotEmpty) 'failureReason': failureReason,
        if (failureCount != null && failureCount > 0) 'failureCount': failureCount,
      },
    );
  }

  String _sanitizeFileName(String name) {
    final normalized = name.replaceAll('\\', '/');
    final lastSegment = normalized.split('/').last.trim();
    if (lastSegment.isEmpty) return 'upload_image';
    return lastSegment.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _extensionFromMimeType(String mimeType) {
    if (mimeType == 'image/jpeg' || mimeType == 'image/jpg') return '.jpg';
    if (mimeType == 'image/webp') return '.webp';
    if (mimeType == 'image/gif') return '.gif';
    if (mimeType == 'image/svg+xml') return '.svg';
    if (mimeType == 'image/bmp') return '.bmp';
    return '.png';
  }

  Future<File> _writeUniqueFile(
    Directory directory,
    String fileName,
    List<int> bytes,
  ) async {
    await directory.create(recursive: true);
    final dotIndex = fileName.lastIndexOf('.');
    final base = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex > 0 ? fileName.substring(dotIndex) : '';
    var candidate = File('${directory.path}${Platform.pathSeparator}$fileName');
    var count = 1;
    while (await candidate.exists()) {
      candidate = File('${directory.path}${Platform.pathSeparator}${base}_$count$ext');
      count++;
    }
    await candidate.writeAsBytes(bytes, flush: true);
    return candidate;
  }

  Future<Map<String, dynamic>> _persistUploadedImage(UploadImageFilePayload file) async {
    final uriData = UriData.parse(file.dataUrl);
    final bytes = uriData.contentAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('empty_upload_image');
    }
    var fileName = _sanitizeFileName(file.name);
    if (!fileName.contains('.')) {
      final ext = _extensionFromMimeType(uriData.mimeType ?? file.type);
      fileName = '$fileName$ext';
    }
    if (widget.baseDirectory != null && widget.baseDirectory!.isNotEmpty) {
      final imagesDir = Directory('${widget.baseDirectory}${Platform.pathSeparator}images');
      final out = await _writeUniqueFile(imagesDir, fileName, bytes);
      final relativeName = out.path.split(Platform.pathSeparator).last;
      return {
        'src': 'images/$relativeName',
        'alt': file.name,
      };
    }
    final out = await _writeUniqueFile(Directory.systemTemp, fileName, bytes);
    return {
      'src': out.path,
      'alt': file.name,
    };
  }

  Future<Map<String, dynamic>> _persistUploadedImageWithRetry(
    UploadImageFilePayload file,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _maxUploadPersistRetries; attempt++) {
      try {
        return await _persistUploadedImage(file);
      } catch (e) {
        lastError = e;
        if (attempt >= _maxUploadPersistRetries) break;
        await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
      }
    }
    throw Exception('persist_image_retries_exhausted:$lastError');
  }

  Future<void> _handleUploadImagesRequest(OnUploadImagesRequestPayload payload) async {
    widget.onUploadImagesRequest?.call(payload);
    var failureCount = 0;
    String? failureReason;
    try {
      final images = <Map<String, dynamic>>[];
      for (final file in payload.files) {
        images.add(await _persistUploadedImageWithRetry(file));
      }
      await _sendUploadImagesResult(
        payload.requestId,
        images: images,
      );
    } catch (e) {
      failureCount += 1;
      final errorText = e.toString();
      if (errorText.contains('empty_upload_image')) {
        failureReason = 'upload_empty_file';
      } else if (errorText.contains('FormatException')) {
        failureReason = 'upload_decode_failed';
      } else if (errorText.contains('FileSystemException')) {
        failureReason = 'upload_write_failed';
      } else if (errorText.contains('persist_image_retries_exhausted')) {
        failureReason = 'upload_persist_retries_exhausted';
      } else {
        failureReason = 'upload_failed';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片上传失败：$failureReason，可重试'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                _handleUploadImagesRequest(payload);
              },
            ),
          ),
        );
      }
      await _sendUploadImagesResult(
        payload.requestId,
        images: const [],
        reason: '$failureReason:$e',
        failureReason: failureReason,
        failureCount: failureCount,
      );
    }
  }

  String _sanitizeInsertImageAlt(String? alt) {
    if (alt == null) return '';
    return alt.replaceAll('\n', ' ').trim();
  }

  Future<Map<String, String>?> _showInsertImageUrlDialog() async {
    if (!mounted || !widget.enableInsertImageUrl) return null;
    final urlController = TextEditingController();
    final altController = TextEditingController();
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.link, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Text('插入图片链接'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '图片 URL',
                    hintText: 'https://example.com/image.png',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altController,
                  decoration: InputDecoration(
                    labelText: '替代文本（可选）',
                    hintText: '用于无障碍与图片说明',
                    prefixIcon: const Icon(Icons.image_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.pop(context, {
                    'url': url,
                    'alt': _sanitizeInsertImageAlt(altController.text),
                  });
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('插入'),
            ),
          ],
        ),
      );
    } finally {
      urlController.dispose();
      altController.dispose();
    }
  }

  Future<Map<String, String>?> _pickInsertImageFromDevice() async {
    if (!widget.enableInsertImagePicker) return null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final imagePath = file.path ?? '';
    if (imagePath.isEmpty) return null;
    if (widget.baseDirectory != null && widget.baseDirectory!.isNotEmpty) {
      final documentPath = '${widget.baseDirectory}${Platform.pathSeparator}__milkdown_insert__.md';
      try {
        final myFilesService = MyFilesService();
        final relativePath = await myFilesService.copyImageToDocument(imagePath, documentPath);
        return {
          'src': relativePath,
          'alt': _sanitizeInsertImageAlt(file.name),
        };
      } catch (_) {
        // fall back to original path
      }
    }
    return {
      'src': imagePath,
      'alt': _sanitizeInsertImageAlt(file.name),
    };
  }

  Future<String?> _chooseInsertImageSource() async {
    if (!mounted) return null;
    return await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('输入图片链接'),
              subtitle: const Text('使用网络图片 URL'),
              enabled: widget.enableInsertImageUrl,
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从设备选择'),
              subtitle: const Text('选择本地图片文件'),
              enabled: widget.enableInsertImagePicker,
              onTap: () => Navigator.pop(context, 'device'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInsertImageRequest(OnInsertImageRequestPayload payload) async {
    try {
      final source = await _chooseInsertImageSource();
      Map<String, String>? selected;
      if (source == 'url') {
        selected = await _showInsertImageUrlDialog();
      } else if (source == 'device') {
        selected = await _pickInsertImageFromDevice();
      }
      if (selected == null) {
        await _sendExecCmd(
          'upload_images_result',
          args: {
            'requestId': payload.requestId,
            'images': const [],
            'reason': 'insert_image_cancelled',
          },
        );
        return;
      }
      final src = selected['src']?.trim() ?? '';
      if (src.isEmpty) {
        await _sendExecCmd(
          'upload_images_result',
          args: {
            'requestId': payload.requestId,
            'images': const [],
            'reason': 'insert_image_invalid_src',
          },
        );
        return;
      }
      await _sendExecCmd(
        'upload_images_result',
        args: {
          'requestId': payload.requestId,
          'images': [
            {
              'src': src,
              'alt': _sanitizeInsertImageAlt(selected['alt']),
            }
          ],
        },
      );
    } catch (e) {
      await _sendExecCmd(
        'upload_images_result',
        args: {
          'requestId': payload.requestId,
          'images': const [],
          'reason': 'insert_image_failed:$e',
        },
      );
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> msg) async {
    final encoded = jsonEncode(msg);
    final encodedLiteral = jsonEncode(encoded);
    await _controller?.evaluateJavascript(
      source: '''
        (function() {
          const raw = $encodedLiteral;
          const m = JSON.parse(raw);
          if (window.__USHIO_BRIDGE__ && window.__USHIO_BRIDGE__.onFlutterMessage) {
            window.__USHIO_BRIDGE__.onFlutterMessage(m);
          }
        })();
      ''',
    );
  }

  Future<void> _handleBridgeArgs(List<dynamic> args) async {
    if (args.isEmpty || args.first is! Map) {
      debugPrint('Milkdown bridge: invalid message args: $args');
      return;
    }
    final map = Map<String, dynamic>.from(args.first as Map);
    widget.onBridgeMessage?.call(map);
    OnUploadImagesRequestPayload? uploadPayload;
    OnInsertImageRequestPayload? insertImagePayload;
    dispatchMilkdownBridgeMessage(
      map,
      onContentChange: (markdown) {
        _lastSyncedMarkdown = markdown;
        widget.onContentChange?.call(markdown);
      },
      onOutlineUpdate: widget.onOutlineUpdate,
      onLinkClick: widget.onLinkClick,
      onImageError: widget.onImageError,
      onUploadImagesRequest: (payload) {
        uploadPayload = payload;
      },
      onInsertImageRequest: (payload) {
        insertImagePayload = payload;
      },
      onCheckboxToggle: widget.onCheckboxToggle,
      onCmdResult: (cmd, ok, reason) {
        if (!ok) {
          debugPrint('Milkdown exec_cmd failed: cmd=$cmd reason=${reason ?? 'unknown'}');
          if (mounted && reason != null && reason.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('编辑命令失败：$cmd（$reason）'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      onRenderComplete: () {
        if (!_didFinishFirstRender) {
          _didFinishFirstRender = true;
        }
        widget.onLoadFinished?.call();
      },
    );
    if (uploadPayload != null) {
      await _handleUploadImagesRequest(uploadPayload!);
    }
    if (insertImagePayload != null) {
      await _handleInsertImageRequest(insertImagePayload!);
    }
  }

  @override
  void didUpdateWidget(covariant MilkdownWebViewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final markdownChanged = oldWidget.initialMarkdown != widget.initialMarkdown;
    final baseChanged = oldWidget.baseDirectory != widget.baseDirectory;
    final readOnlyChanged = oldWidget.readOnly != widget.readOnly;
    if (markdownChanged || baseChanged || readOnlyChanged) {
      if (_suppressNextReload && markdownChanged) {
        _suppressNextReload = false;
      } else if (_lastSyncedMarkdown != widget.initialMarkdown || baseChanged || readOnlyChanged) {
        _sendInitDoc();
      }
    }
    if (oldWidget.bodyFont != widget.bodyFont ||
        oldWidget.monoFont != widget.monoFont ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight) {
      _sendTheme();
    }
    _syncThemeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncThemeIfNeeded();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    final server = _localhostServer;
    _localhostServer = null;
    if (server != null) {
      server.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialUrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initialUrl!.isEmpty) {
      return const Center(child: Text('Failed to start Milkdown localhost server'));
    }

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_initialUrl!)),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccess: true,
        javaScriptEnabled: true,
        disableContextMenu: true,
        supportZoom: false,
        builtInZoomControls: false,
        displayZoomControls: false,
        resourceCustomSchemes: [_localFileScheme],
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        widget.controller?._attach(this);
        widget.controller?._attachWebViewController(controller);
        controller.addJavaScriptHandler(
          handlerName: 'bridge',
          callback: (args) async {
            await _handleBridgeArgs(args);
            return {'ok': true};
          },
        );
      },
      onLoadStop: (controller, _) async {
        await _sendInitDoc();
        await _sendTheme();
      },
      onLoadResourceWithCustomScheme: (controller, request) async {
        final url = request.url;
        if (url == null) return null;
        return _serveLocalFileRequest(Uri.parse(url.toString()));
      },
    );
  }
}

String _toCssHex(Color color) {
  final r = color.red.toRadixString(16).padLeft(2, '0');
  final g = color.green.toRadixString(16).padLeft(2, '0');
  final b = color.blue.toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

String _toCssRgba(Color color) {
  final r = color.red;
  final g = color.green;
  final b = color.blue;
  final a = color.opacity;
  return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
}
