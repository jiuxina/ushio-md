import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/milkdown_bridge.dart';

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
  Future<void> focusEditor() => execCmd('focus_editor');
  Future<void> insertImage({required String src, String? alt}) =>
      execCmd('insert_image', args: {
        'src': src,
        if (alt != null) 'alt': alt,
      });

  Future<void> scrollToHeading(int headingIndex, {double topOffset = 32.0}) async {
    await _webViewController?.evaluateJavascript(
      source: '''
        (function() {
          var el = document.getElementById('heading-' + $headingIndex);
          if (!el) return;
          el.scrollIntoView({ block: 'start' });
          window.scrollBy(0, -$topOffset);
          el.classList.add('heading-flash');
          setTimeout(function() { el.classList.remove('heading-flash'); }, 700);
        })();
      ''',
    );
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

  InAppWebViewController? _controller;
  InAppLocalhostServer? _localhostServer;
  String? _initialUrl;
  String? _lastThemeSignature;
  String? _lastSyncedMarkdown;
  bool _isServerStarting = false;
  bool _didFinishFirstRender = false;
  bool _suppressNextReload = false;

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
  }) async {
    await _sendExecCmd(
      'upload_images_result',
      args: {
        'requestId': requestId,
        'images': images,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
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

  Future<void> _handleUploadImagesRequest(OnUploadImagesRequestPayload payload) async {
    widget.onUploadImagesRequest?.call(payload);
    try {
      final images = <Map<String, dynamic>>[];
      for (final file in payload.files) {
        images.add(await _persistUploadedImage(file));
      }
      await _sendUploadImagesResult(
        payload.requestId,
        images: images,
      );
    } catch (e) {
      await _sendUploadImagesResult(
        payload.requestId,
        images: const [],
        reason: 'upload_failed:$e',
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
      onCheckboxToggle: widget.onCheckboxToggle,
      onCmdResult: (cmd, ok, reason) {
        if (!ok) {
          debugPrint('Milkdown exec_cmd failed: cmd=$cmd reason=${reason ?? 'unknown'}');
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
