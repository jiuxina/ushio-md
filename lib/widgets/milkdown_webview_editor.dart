import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/milkdown_bridge.dart';

typedef MilkdownBridgeMessageHandler = void Function(Map<String, dynamic> msg);

class MilkdownWebViewEditor extends StatefulWidget {
  final String initialMarkdown;
  final ValueChanged<String>? onContentChange;
  final MilkdownBridgeMessageHandler? onBridgeMessage;

  const MilkdownWebViewEditor({
    super.key,
    required this.initialMarkdown,
    this.onContentChange,
    this.onBridgeMessage,
  });

  @override
  State<MilkdownWebViewEditor> createState() => _MilkdownWebViewEditorState();
}

class _MilkdownWebViewEditorState extends State<MilkdownWebViewEditor> {
  InAppWebViewController? _controller;
  Uint8List? _htmlData;

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

  Future<void> _sendInitDoc() async {
    final msg = BridgeEnvelope<InitDocPayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'init_doc',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: InitDocPayload(markdown: widget.initialMarkdown),
    );
    await _sendMessage(msg.toJson((payload) => payload.toJson()));
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
      },
    );
  }
}
