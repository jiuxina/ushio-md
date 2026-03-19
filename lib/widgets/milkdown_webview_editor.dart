import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/milkdown_bridge.dart';

typedef MilkdownBridgeMessageHandler = void Function(Map<String, dynamic> msg);

class MilkdownWebViewController {
  _MilkdownWebViewEditorState? _state;

  void _attach(_MilkdownWebViewEditorState state) {
    _state = state;
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

  static const _assetPath = 'assets/milkdown_web/index.html';

  @override
  void initState() {
    super.initState();
    _loadHtmlAsset();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
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
    final bodyFont = widget.bodyFont ?? 'Noto Sans SC';
    final monoFont = widget.monoFont ?? 'JetBrains Mono';
    final fontSize = widget.fontSize ?? 16.0;
    final lineHeight = widget.lineHeight ?? 1.7;
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
    }
  }

  @override
  void didUpdateWidget(covariant MilkdownWebViewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;
    if (oldWidget.initialMarkdown != widget.initialMarkdown) {
      _sendInitDoc();
    }
    if (oldWidget.bodyFont != widget.bodyFont ||
        oldWidget.monoFont != widget.monoFont ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight) {
      _sendTheme();
      return;
    }
    final sig = _themeSignature();
    if (_lastThemeSignature != sig) {
      _sendTheme();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) return;
    final sig = _themeSignature();
    if (_lastThemeSignature != sig) {
      _sendTheme();
    }
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
        allowFileAccess: false,
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
