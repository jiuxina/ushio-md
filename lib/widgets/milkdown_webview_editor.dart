import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import '../models/milkdown_bridge.dart';

typedef MilkdownBridgeMessageHandler = void Function(Map<String, dynamic> msg);

const _defaultBodyFont = 'Noto Sans SC';
const _defaultMonoFont = 'JetBrains Mono';
const _defaultFontSize = 16.0;
const _defaultLineHeight = 1.7;

class MilkdownWebViewController {
  _MilkdownWebViewEditorState? _state;

  void _attach(_MilkdownWebViewEditorState state) {
    _state = state;
  }

  void _detach(_MilkdownWebViewEditorState state) {
    if (identical(_state, state)) {
      _state = null;
    }
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
}

class MilkdownWebViewEditor extends StatefulWidget {
  final String initialMarkdown;
  final ValueChanged<String>? onContentChange;
  final MilkdownBridgeMessageHandler? onBridgeMessage;
  final ValueChanged<OnImageErrorPayload>? onImageError;
  final ValueChanged<OnOutlineUpdatePayload>? onOutlineUpdate;
  final ValueChanged<OnLinkClickPayload>? onLinkClick;
  final MilkdownWebViewController? controller;
  final String? bodyFont;
  final String? monoFont;
  final double? fontSize;
  final double? lineHeight;

  const MilkdownWebViewEditor({
    super.key,
    required this.initialMarkdown,
    this.onContentChange,
    this.onBridgeMessage,
    this.onImageError,
    this.onOutlineUpdate,
    this.onLinkClick,
    this.controller,
    this.bodyFont,
    this.monoFont,
    this.fontSize,
    this.lineHeight,
  });

  @override
  State<MilkdownWebViewEditor> createState() => _MilkdownWebViewEditorState();
}

class _MilkdownWebViewEditorState extends State<MilkdownWebViewEditor> {
  InAppWebViewController? _controller;
  Uint8List? _htmlData;
  String? _lastThemeSignature;
  String? _imageBaseUrl;

  static const _assetPath = 'assets/milkdown_web/index.html';
  static const _imageDirName = 'md_images';

  @override
  void initState() {
    super.initState();
    _loadHtmlAsset();
    _initImageRouting();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
  }

  Future<void> _initImageRouting() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory.fromUri(appDir.uri.resolve(_imageDirName));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      if (!mounted) return;
      final imageDirUrl = Uri.directory(imageDir.path).toString();
      setState(() {
        _imageBaseUrl = imageDirUrl;
      });
    } catch (e) {
      debugPrint(
        'Milkdown image routing init failed (non-fatal, image base routing disabled): $e',
      );
    }
  }

  Future<void> _loadHtmlAsset() async {
    try {
      final html = await rootBundle.loadString(_assetPath);
      if (!mounted) return;
      setState(() => _htmlData = Uint8List.fromList(utf8.encode(html)));
    } catch (e) {
      debugPrint('Failed to load Milkdown asset $_assetPath: $e');
      if (!mounted) return;
      setState(() => _htmlData = Uint8List(0));
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
        // Material 3 favors surface-based backgrounds; keep the same token for
        // now to avoid introducing an app-specific background divergence.
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
    final msg = BridgeEnvelope<InitDocPayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'init_doc',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: InitDocPayload(markdown: markdownOverride ?? widget.initialMarkdown),
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

  void _handleBridgeArgs(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) {
      debugPrint('Milkdown bridge: invalid message args: $args');
      return;
    }
    final map = Map<String, dynamic>.from(args.first as Map);
    widget.onBridgeMessage?.call(map);

    final type = map['type'] as String?;
    if (type == 'on_content_change') {
      final payload = map['payload'];
      if (payload is Map) {
        final markdown = payload['markdown'];
        if (markdown is String) {
          widget.onContentChange?.call(markdown);
        }
      }
    } else if (type == 'on_outline_update') {
      final payload = map['payload'];
      if (payload is Map) {
        widget.onOutlineUpdate?.call(
          OnOutlineUpdatePayload.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    } else if (type == 'on_link_click') {
      final payload = map['payload'];
      if (payload is Map) {
        widget.onLinkClick?.call(
          OnLinkClickPayload.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    } else if (type == 'on_image_error') {
      final payload = map['payload'];
      if (payload is Map) {
        widget.onImageError?.call(
          OnImageErrorPayload.fromJson(Map<String, dynamic>.from(payload)),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant MilkdownWebViewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMarkdown != widget.initialMarkdown) {
      _sendInitDoc();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_htmlData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_htmlData!.isEmpty) {
      return const Center(child: Text('Failed to load Milkdown assets'));
    }

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: utf8.decode(_htmlData!),
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        // Needed for local file:// image rendering when src points to app-private
        // directory URLs; cross-file-origin access remains disabled above.
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
        controller.addJavaScriptHandler(
          handlerName: 'bridge',
          callback: (args) async {
            _handleBridgeArgs(args);
            return {'ok': true};
          },
        );
      },
      onLoadStop: (controller, _) async {
        await _sendInitDoc();
        if (_imageBaseUrl != null) {
          await _sendExecCmd('set_image_base', args: {'baseUrl': _imageBaseUrl});
        }
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
