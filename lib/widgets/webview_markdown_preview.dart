import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';

final RegExp _blockMathRegex =
    RegExp(r'(?<!\\)\$\$[\s\S]+?(?<!\\)\$\$', multiLine: true);
final RegExp _inlineMathRegex = RegExp(
  r'(?<!\\)(?<!\$)\$(?!\$)(?:[^\n\$]|\\\$)+?(?<!\\)\$(?!\$)',
);
final RegExp _latexInlineMathRegex = RegExp(r'\\\((?:[\s\S]+?)\\\)');
final RegExp _latexBlockMathRegex = RegExp(r'\\\[(?:[\s\S]+?)\\\]', multiLine: true);

/// Returns true when the markdown likely contains KaTeX-style math syntax.
///
/// We use this to avoid loading remote KaTeX assets for normal documents,
/// which makes first-run preview startup much faster on fresh installs.
bool markdownNeedsMathRendering(String data) {
  if (data.isEmpty) return false;
  return _blockMathRegex.hasMatch(data) ||
      _inlineMathRegex.hasMatch(data) ||
      _latexInlineMathRegex.hasMatch(data) ||
      _latexBlockMathRegex.hasMatch(data);
}

final Map<String, String> _previewFontFilePaths = <String, String>{};
Completer<void>? _previewFontCompleter;

/// 预热 Markdown 预览所需资源。
///
/// 首次启动或首次打开大文档时可提前调用，避免进入编辑器后再等待字体资源
/// 解压与 WebView 相关初始化。
Future<void> warmUpMarkdownPreviewAssets() async {
  if (_previewFontCompleter != null) {
    await _previewFontCompleter!.future.catchError((_) {});
    return;
  }

  _previewFontCompleter = Completer<void>();
  try {
    final dir = await getTemporaryDirectory();
    const assets = [
      'assets/fonts/NotoSansSC-Regular.ttf',
      'assets/fonts/JetBrainsMono-Regular.ttf',
    ];

    for (final asset in assets) {
      final filename = asset.split('/').last;
      final file = File('${dir.path}/$filename');
      if (!file.existsSync()) {
        final data = await rootBundle.load(asset);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      _previewFontFilePaths[asset] = file.path;
    }

    _previewFontCompleter!.complete();
  } catch (_) {
    if (!_previewFontCompleter!.isCompleted) {
      _previewFontCompleter!.complete();
    }
  }
}

/// Controller for the WebView-based markdown preview.
///
/// Exposes [scrollToHeading] to navigate to a heading by its sequential index
/// in the rendered document, [scrollToText] to jump to a text match, and
/// [suppressNextReload] to skip the next content reload (e.g. after a
/// checkbox toggle that is already reflected in the WebView).
class MarkdownWebViewController {
  InAppWebViewController? _webViewController;
  _WebViewMarkdownPreviewState? _state;

  void _attach(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void _attachState(_WebViewMarkdownPreviewState state) {
    _state = state;
  }

  /// Suppress the next content reload triggered by [didUpdateWidget].
  ///
  /// Call this before updating the underlying data when the visual state is
  /// already correct in the WebView (e.g. after a checkbox toggle).
  void suppressNextReload() {
    _state?._suppressNextReload = true;
    _state?._debounceTimer?.cancel(); // also kill any pending reload immediately
  }

  /// Scroll to heading number [headingIndex] (0-based, in document order).
  Future<void> scrollToHeading(int headingIndex,
      {double topOffset = 32.0}) async {
    await _webViewController?.evaluateJavascript(source: '''
      (function() {
        var el = document.getElementById('heading-$headingIndex');
        if (!el) return;
        el.scrollIntoView({block: 'start'});
        window.scrollBy(0, -$topOffset);
        el.classList.add('heading-flash');
        setTimeout(function() { el.classList.remove('heading-flash'); }, 700);
      })();
    ''');
  }

  /// Scroll the WebView to the first occurrence of [text], with a brief
  /// highlight so the user can see the match.
  Future<void> scrollToText(String text) async {
    if (text.isEmpty) return;
    // Escape single quotes and backslashes for the JS string literal
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _webViewController?.evaluateJavascript(source: '''
      (function() {
        var search = '$escaped'.trim();
        if (!search) return;
        var walker = document.createTreeWalker(
          document.body, NodeFilter.SHOW_TEXT, null, false);
        var node;
        while ((node = walker.nextNode())) {
          var idx = node.nodeValue ? node.nodeValue.indexOf(search) : -1;
          if (idx !== -1) {
            var el = node.parentElement;
            if (el) {
              el.scrollIntoView({block: 'center'});
              var orig = el.style.backgroundColor;
              el.style.backgroundColor = 'rgba(255,200,0,0.5)';
              setTimeout(function() { el.style.backgroundColor = orig; }, 1200);
            }
            return;
          }
        }
      })();
    ''');
  }

  /// Capture a screenshot of the current WebView content.
  Future<Uint8List?> captureScreenshot() async {
    try {
      return await _webViewController?.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  /// Capture a full-page screenshot by scrolling and stitching viewport shots.
  Future<Uint8List?> captureFullPageScreenshot({
    int maxShots = 30,
    Duration settleDelay = const Duration(milliseconds: 80),
  }) async {
    final c = _webViewController;
    if (c == null) return null;

    try {
      final originalYRaw =
          await c.evaluateJavascript(source: 'window.scrollY || 0');
      final vhRaw =
          await c.evaluateJavascript(source: 'window.innerHeight || 0');
      final shRaw = await c.evaluateJavascript(
          source: 'Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) || 0');

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

/// WebView-based markdown preview widget.
///
/// Converts [data] (Markdown text) to HTML and renders it inside an embedded
/// [InAppWebView].  Supports:
/// - Dark and light themes driven by [isDark].
/// - Custom font sizes ([fontSize]) and families ([fontFamily]).
/// - Resolving local images relative to [baseDirectory].
/// - Link taps forwarded through [onTapLink].
/// - Interactive task-list checkboxes via [onCheckboxChanged].
/// - TOC heading navigation via [MarkdownWebViewController.scrollToHeading].
///
/// Content is debounced (300 ms) before reloading so rapid updates (e.g. live
/// split-mode editing) do not cause visible flicker.
class WebViewMarkdownPreview extends StatefulWidget {
  final String data;
  final bool isDark;
  final double fontSize;
  final String? fontFamily;
  /// Override background color (from the selected theme scheme).
  final Color? bgColor;
  /// Override foreground/text color (from the selected theme scheme).
  final Color? fgColor;
  /// Font family used in code blocks.
  final String? codeFont;
  final String? baseDirectory;
  final void Function(String text, String? href, String title)? onTapLink;
  final Function(int index, bool value) onCheckboxChanged;
  final String? Function(String type, int p1, int p2, int p3, String extra)? onGetMarkdown;
  final void Function(String key, String newText)? onInPlaceEdit;
  final VoidCallback? onLoadFinished;
  final MarkdownWebViewController? controller;
  /// Hide html/body scrollbars inside WebView.
  final bool hidePageScrollbar;
  /// Extra bottom padding (pixels) added to the HTML body to prevent content
  /// being obscured by a floating toolbar or the system navigation bar.
  final double bottomPadding;

  const WebViewMarkdownPreview({
    super.key,
    required this.data,
    required this.isDark,
    required this.fontSize,
    this.fontFamily,
    this.bgColor,
    this.fgColor,
    this.codeFont,
    this.baseDirectory,
    this.onTapLink,
    required this.onCheckboxChanged,
    this.onGetMarkdown,
    this.onInPlaceEdit,
    this.onLoadFinished,
    this.controller,
    this.hidePageScrollbar = false,
    this.bottomPadding = 0,
  });

  @override
  State<WebViewMarkdownPreview> createState() =>
      _WebViewMarkdownPreviewState();
}

class _WebViewMarkdownPreviewState extends State<WebViewMarkdownPreview> {
  InAppWebViewController? _webViewController;
  Timer? _debounceTimer;
  bool _suppressNextReload = false;
  double _savedScrollY = 0;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    _ensureFontsExtracted();
  }

  /// Extract bundled font files to a temp directory once and cache their paths.
  ///
  /// After extraction completes, reload the WebView (if already created) so it
  /// picks up the @font-face rules that reference the extracted files.
  Future<void> _ensureFontsExtracted() async {
    await warmUpMarkdownPreviewAssets();
    if (mounted) _triggerFontReload();
  }

  /// Reload the WebView content with @font-face rules once both the WebView
  /// and the font files are ready.
  void _triggerFontReload() {
    if (_webViewReady && (_previewFontCompleter?.isCompleted ?? false)) {
      _loadContent();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(WebViewMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.isDark != widget.isDark ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.fontFamily != widget.fontFamily ||
        oldWidget.bgColor != widget.bgColor ||
        oldWidget.fgColor != widget.fgColor ||
        oldWidget.codeFont != widget.codeFont) {
      if (_suppressNextReload) {
        _suppressNextReload = false;
        _debounceTimer?.cancel(); // prevent any pending reload from firing
        return;
      }
      _debounceTimer?.cancel();
      _debounceTimer =
          Timer(const Duration(milliseconds: 300), _loadContent);
    }
  }

  void _loadContent() async {
    if (_webViewController == null) return;
    // Save scroll position so we can restore it after the reload
    try {
      final result = await _webViewController!
          .evaluateJavascript(source: 'window.scrollY');
      _savedScrollY = double.tryParse(result?.toString() ?? '0') ?? 0;
    } catch (_) {
      _savedScrollY = 0;
    }
    final html = _buildHtml();
    final baseUrl = _makeBaseUrl();
    _webViewController!.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: baseUrl,
    );
  }

  WebUri? _makeBaseUrl() {
    final dir = widget.baseDirectory;
    if (dir == null) return null;
    if (Platform.isWindows) {
      // Windows needs forward slashes: file:///C:/path/to/dir/
      return WebUri('file:///${dir.replaceAll('\\', '/')}/');
    }
    return WebUri('file://$dir/');
  }

  /// Convert Markdown [widget.data] to a complete HTML document string.
  String _buildHtml() {
    // Protect math expressions before markdown parsing only when needed so
    // regular documents do not pay the startup cost of loading KaTeX assets.
    final useMathRendering = markdownNeedsMathRendering(widget.data);
    final mathBlocks = <String>[];
    var src = widget.data;

    if (useMathRendering) {
      // Block math  $$...$$  (may span multiple lines)
      src = src.replaceAllMapped(
        _blockMathRegex,
        (m) {
          final idx = mathBlocks.length;
          final content = m.group(0)!.substring(2, m.group(0)!.length - 2);
          mathBlocks.add('<div class="math-block">\\[$content\\]</div>');
          return '\n<!-- MATHBLOCK$idx -->\n';
        },
      );

      // Inline math  $...$  (single line, no nesting)
      src = src.replaceAllMapped(
        _inlineMathRegex,
        (m) {
          final idx = mathBlocks.length;
          final content = m.group(0)!.substring(1, m.group(0)!.length - 1);
          mathBlocks.add('<span class="math-inline">\\($content\\)</span>');
          return '<!-- MATHBLOCK$idx -->';
        },
      );
    }

    // 1b. ==highlight== → <mark>text</mark>  (before markdown parsing)
    src = src.replaceAllMapped(
      RegExp(r'==([^=\n]+)=='),
      (m) => '<mark>${m.group(1)}</mark>',
    );

    // 2. Markdown → HTML (GitHub Flavoured Markdown)
    var htmlBody = md.markdownToHtml(
      src,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    // 3. Restore math placeholders
    for (int i = 0; i < mathBlocks.length; i++) {
      htmlBody = htmlBody.replaceAll('<!-- MATHBLOCK$i -->', mathBlocks[i]);
    }

    // 4. Add sequential id="heading-N" to every heading tag for TOC navigation
    int headingIdx = 0;
    final withIds = htmlBody.replaceAllMapped(
      RegExp(r'<(h[1-6])(\s[^>]*)?>'),
      (m) {
        final tag = m.group(1)!;
        final attrs = m.group(2) ?? '';
        return '<$tag id="heading-${headingIdx++}"$attrs>';
      },
    );

    // 5. Make task-list checkboxes interactive (remove the `disabled` attr)
    var processed = withIds.replaceAll(
      RegExp(r'<input\s+type="checkbox"\s+disabled'),
      '<input type="checkbox"',
    );

    // 6. Convert <img> tags whose src ends in a video extension to <video>
    processed = processed.replaceAllMapped(
      RegExp(r'<img\s[^>]*src="([^"]*\.(mp4|webm|mov|avi|mkv))"[^>]*>',
          caseSensitive: false),
      (m) {
        final src = m.group(1)!;
        return '<video controls class="media-player"><source src="$src">您的浏览器不支持视频播放。</video>';
      },
    );

    // 7. Convert <img> tags whose src ends in an audio extension to <audio>
    processed = processed.replaceAllMapped(
      RegExp(r'<img\s[^>]*src="([^"]*\.(mp3|wav|ogg|aac|flac|m4a))"[^>]*>',
          caseSensitive: false),
      (m) {
        final src = m.group(1)!;
        return '<audio controls class="media-player"><source src="$src">您的浏览器不支持音频播放。</audio>';
      },
    );

    return _wrapHtml(processed, useMathRendering: useMathRendering);
  }

  /// Convert a Flutter [Color] to a CSS hex string (e.g. `#1a1a2e`).
  String _hex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';

  /// Wrap [body] in a full HTML document with inline CSS and JS.
  String _wrapHtml(String body, {required bool useMathRendering}) {
    final dark = widget.isDark;
    final fs = widget.fontSize;
    final ff = widget.fontFamily;
    // Raw markdown embedded as JS variable so in-place editing can look up
    // block/cell content synchronously without a Dart↔JS bridge round-trip.
    final rawMdJson = jsonEncode(widget.data);

    // ── Colour palette ────────────────────────────────────────────────────
    // Use theme-scheme colours when provided, otherwise fall back to defaults.
    final bg = widget.bgColor != null
        ? _hex(widget.bgColor!)
        : (dark ? '#1a1a2e' : '#ffffff');
    final fg = widget.fgColor != null
        ? _hex(widget.fgColor!)
        : (dark ? '#e0e0e0' : '#1a1a1a');
    final hColor = dark ? '#ffffff' : '#111111';
    final codeBg = dark ? '#282c34' : '#f5f5f5';
    final codeColor = dark ? '#abb2bf' : '#333333';
    final codeBlockBg = dark ? '#1e2028' : '#f8f8f8';
    final codeBlockBorder = dark ? '#3d3d3d' : '#e0e0e0';
    final bqBorder = dark ? '#448aff' : '#007aff';
    final bqBg = dark
        ? 'rgba(68,138,255,0.1)'
        : 'rgba(0,122,255,0.05)';
    final linkColor = dark ? '#64b5f6' : '#007aff';
    final tblBorder = dark ? '#3d3d3d' : '#e0e0e0';
    final tblHeadBg = dark ? '#252535' : '#f5f5f5';
    final hrColor = dark ? '#3d3d3d' : '#e0e0e0';
    final delColor = dark ? '#888888' : '#999999';

    // ── Font families ─────────────────────────────────────────────────────
    final bodyFont = ff != null
        ? '"$ff", system-ui, -apple-system, sans-serif'
        : 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    final cf = widget.codeFont;
    final monoFont = cf != null && cf != 'System'
        ? '"$cf", JetBrains Mono, Consolas, Monaco, "Courier New", monospace'
        : 'JetBrains Mono, Consolas, Monaco, "Courier New", monospace';

    // ── Heading flash animation ───────────────────────────────────────────
    final flashKf = dark
        ? '@keyframes hflash { 0%{background:transparent} 20%{background:rgba(100,180,255,0.35)} 100%{background:transparent} }'
        : '@keyframes hflash { 0%{background:transparent} 20%{background:rgba(0,122,255,0.25)} 100%{background:transparent} }';
    final scrollbarCss = widget.hidePageScrollbar
        ? 'html,body{scrollbar-width:none;-ms-overflow-style:none;}html::-webkit-scrollbar,body::-webkit-scrollbar{width:0;height:0;display:none;}'
        : '';

    // ── @font-face rules (use extracted temp-dir files via file:// URI) ─────
    String fontFaces = '';
    void addFontFace(String family, String assetKey) {
      final path = _previewFontFilePaths[assetKey];
      if (path == null) return;
      final uri = Platform.isWindows
          ? 'file:///${path.replaceAll('\\', '/')}'
          : 'file://$path';
      fontFaces +=
          "@font-face{font-family:'$family';src:url('$uri') format('truetype');"
          "font-weight:normal;font-style:normal;}\n";
    }
    addFontFace('Noto Sans SC', 'assets/fonts/NotoSansSC-Regular.ttf');
    addFontFace('JetBrains Mono', 'assets/fonts/JetBrainsMono-Regular.ttf');

    final mathAssets = useMathRendering
        ? '''<!-- KaTeX for math rendering -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css" crossorigin="anonymous">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js" crossorigin="anonymous"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js" crossorigin="anonymous"
  onload="renderMathInElement(document.body,{delimiters:[{left:'\$\$',right:'\$\$',display:true},{left:'\$',right:'\$',display:false},{left:'\\\\(',right:'\\\\)',display:false},{left:'\\\\[',right:'\\\\]',display:true}],throwOnError:false});"></script>'''
        : '';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=yes">
$mathAssets
<style>
$fontFaces
*{box-sizing:border-box}
body{background:$bg;color:$fg;font-family:$bodyFont;font-size:${fs}px;line-height:1.6;padding:16px 16px ${(16 + widget.bottomPadding).toInt()}px 16px;margin:0;word-wrap:break-word;overflow-wrap:break-word;touch-action:manipulation}
h1,h2,h3,h4,h5,h6{color:$hColor;font-weight:bold;line-height:1.4;margin:1em 0 0.5em;border-radius:4px}
h1{font-size:${fs * 2}px;border-bottom:2px solid $hrColor;padding-bottom:0.3em}
h2{font-size:${fs * 1.5}px;border-bottom:1px solid $hrColor;padding-bottom:0.2em}
h3{font-size:${fs * 1.25}px}h4{font-size:${fs * 1.1}px}h5{font-size:${fs}px}h6{font-size:${fs * 0.9}px}
$flashKf
$scrollbarCss
.heading-flash{animation:hflash 0.7s ease-out forwards}
p{margin:0.8em 0}
a{color:$linkColor;text-decoration:none}a:hover{text-decoration:underline}
code{background:$codeBg;color:$codeColor;font-family:$monoFont;font-size:${fs * 0.9}px;padding:2px 6px;border-radius:4px}
pre{background:$codeBlockBg;border:1px solid $codeBlockBorder;border-radius:8px;padding:16px;overflow-x:auto;margin:1em 0}
pre code{background:none;color:$codeColor;padding:0;border-radius:0;font-size:${fs * 0.85}px;line-height:1.5}
blockquote{border-left:4px solid $bqBorder;background:$bqBg;margin:1em 0;padding:8px 8px 8px 16px;border-radius:0 4px 4px 0}
blockquote p{margin:0}
table{border-collapse:collapse;width:100%;margin:1em 0;border-radius:6px;overflow:hidden}
th,td{border:1px solid $tblBorder;padding:8px 12px}
th{background:$tblHeadBg;font-weight:bold}
img{max-width:100%;height:auto;display:block;margin:0.5em auto;border-radius:4px}
ul,ol{padding-left:1.5em;margin:0.5em 0}li{margin:0.3em 0}
input[type="checkbox"]{margin-right:6px;width:${fs * 0.9}px;height:${fs * 0.9}px;vertical-align:middle;cursor:pointer}
hr{border:none;border-top:1px solid $hrColor;margin:1.5em 0}
del{color:$delColor}
mark{background:rgba(255,220,0,0.5);border-radius:2px;padding:0 2px}
/* Code language badge */
pre{position:relative}
pre[data-language]::before{content:attr(data-language);position:absolute;top:6px;right:12px;font-size:${fs * 0.75}px;color:${dark ? '#888' : '#aaa'};font-family:$monoFont;text-transform:uppercase;letter-spacing:0.05em;user-select:none;pointer-events:none}

.math-block{overflow-x:auto;padding:8px 0;margin:1em 0;text-align:center}
.math-inline{display:inline}
.katex-display{overflow-x:auto;overflow-y:hidden;padding:4px 0}
/* Media players */
.media-player{width:100%;max-width:100%;border-radius:8px;margin:0.5em auto;display:block;background:#000}
/* GitHub Alerts */
.gh-alert{border-radius:6px;padding:12px;margin:1em 0}
.gh-alert-title{font-weight:bold;margin-bottom:6px;display:flex;align-items:center;gap:6px}
.gh-alert-note{border-left:4px solid #0969da;background:rgba(9,105,218,0.1)}
.gh-alert-tip{border-left:4px solid #1a7f37;background:rgba(26,127,55,0.1)}
.gh-alert-important{border-left:4px solid #8250df;background:rgba(130,80,223,0.1)}
.gh-alert-warning{border-left:4px solid #bf8700;background:rgba(191,135,0,0.1)}
.gh-alert-caution{border-left:4px solid #cf222e;background:rgba(207,34,46,0.1)}
.gh-alert-note .gh-alert-title{color:#0969da}
.gh-alert-tip .gh-alert-title{color:#1a7f37}
.gh-alert-important .gh-alert-title{color:#8250df}
.gh-alert-warning .gh-alert-title{color:#bf8700}
.gh-alert-caution .gh-alert-title{color:#cf222e}
</style>
</head>
<body>
$body
<script>
(function(){
  // ── Embedded raw markdown (JSON-encoded by Dart) ──────────────────────
  var __rawMd = $rawMdJson;

  // ── Code language badges ──────────────────────────────────────────────
  document.querySelectorAll('pre code').forEach(function(code) {
    var m = code.className.match(/language-([\\w+\\-]+)/);
    if (m) code.parentNode.setAttribute('data-language', m[1]);
  });

  // ── Markdown marker stripping (block ↔ innerText matching) ───────────
  function _stripMd(t) {
    return t
      .replace(/^```[^\\n]*\$/gm, '').replace(/^~~~[^\\n]*\$/gm, '')
      .replace(/^\\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\\]\\s*/gim, '')
      .replace(/\\*{1,3}([^*\\n]+)\\*{1,3}/g, '\$1')
      .replace(/_{1,3}([^_\\n]+)_{1,3}/g, '\$1')
      .replace(/`+([^`\\n]+)`+/g, '\$1')
      .replace(/~~([^~\\n]+)~~/g, '\$1')
      .replace(/==([^=\\n]+)==/g, '\$1')
      .replace(/!\\[[^\\]]*\\]\\([^)]*\\)/g, '')
      .replace(/\\[([^\\]]*)\\]\\([^)]*\\)/g, '\$1')
      .replace(/^#{1,6}\\s+/gm, '').replace(/^[-*+]\\s+/gm, '')
      .replace(/^\\d+\\.\\s+/gm, '').replace(/^\\s*(>\\s*)+/gm, '')
      .trim().toLowerCase();
  }

  // ── Parse raw markdown into logical blocks (mirrors Dart _parseBlocks) ─
  function _parseRawBlocks() {
    var lines = __rawMd.split('\\n'), blocks = [], i = 0;
    while (i < lines.length) {
      var t = lines[i].trim();
      if (/^\\s*```/.test(t) || /^\\s*~~~/.test(t)) {
        var fm = t.match(/^\\s*(`{3}|~{3})/), fence = fm ? fm[1] : '```';
        var end = i + 1;
        while (end < lines.length && lines[end].trim().indexOf(fence) === -1) end++;
        if (end < lines.length) end++;
        blocks.push(lines.slice(i, end).join('\\n')); i = end; continue;
      }
      if (/^\\s*\\|/.test(lines[i]) && i + 1 < lines.length && /^\\s*\\|/.test(lines[i + 1])) {
        var end = i;
        while (end < lines.length && /^\\s*\\|/.test(lines[end])) end++;
        blocks.push(lines.slice(i, end).join('\\n')); i = end; continue;
      }
      if (/^\\s*>/.test(t)) {
        var end = i;
        while (end < lines.length && /^\\s*>/.test(lines[end].trim())) end++;
        blocks.push(lines.slice(i, end).join('\\n')); i = end; continue;
      }
      if (t) blocks.push(lines[i]);
      i++;
    }
    return blocks;
  }

  // ── Get raw markdown matching the rendered innerText of a block ────────
  function _findBlockMatch(innerText) {
    var search = innerText.trim().toLowerCase().replace(/\s+/g, ' ').slice(0, 100);
    if (!search) return { md: innerText, index: -1 };
    var blocks = _parseRawBlocks(), best = '', score = 0, bestIndex = -1;
    for (var b = 0; b < blocks.length; b++) {
      var s = _stripMd(blocks[b]).replace(/\s+/g, ' ');
      if (!s) continue;
      var sh = s.length <= search.length ? s : search;
      var lo = s.length > search.length ? s : search;
      if (lo.indexOf(sh) !== -1 && sh.length > score) {
        score = sh.length;
        best = blocks[b];
        bestIndex = b;
      }
    }
    return { md: (best || innerText), index: bestIndex };
  }

  function _setBlockSource(el, fallbackText) {
    if (!el) return;
    var match = _findBlockMatch(fallbackText || el.innerText || el.textContent || '');
    if (el.dataset) {
      el.dataset.mdSrc = match.md || fallbackText || '';
      el.dataset.mdBlockIndex = String(match.index);
    }
  }

  function _getBlockMd(innerText) {
    return _findBlockMatch(innerText).md;
  }

  // ── Get raw markdown for a specific table cell ────────────────────────
  function _getCellMd(ti, ri, ci) {
    var sep = /^[\\|\\s\\-:]+\$/, lines = __rawMd.split('\\n');
    var tIdx = 0, inT = false, rows = [];
    for (var i = 0; i <= lines.length; i++) {
      var line = i < lines.length ? lines[i] : '', t = line.trim();
      if (/^\\s*\\|/.test(line) && t) {
        if (!inT) { inT = true; rows = []; }
        if (!sep.test(t)) rows.push(line);
      } else {
        if (inT) {
          if (tIdx === ti) {
            if (ri < rows.length) { var p = rows[ri].split('|'); return ci+1<p.length ? p[ci+1].trim() : ''; }
            return '';
          }
          tIdx++; inT = false; rows = [];
        }
      }
    }
    return '';
  }

  // ── In-place editing ──────────────────────────────────────────────────
  var _ie = null;
  function _startEdit(el, key, rawMd) {
    if (_ie) _commitEdit(true);
    var displayText = rawMd || el.textContent || '';
    var ta = document.createElement('textarea');
    ta.value = displayText;
    ta.setAttribute('spellcheck', 'false');
    ta.style.width = '100%';
    ta.style.minHeight = '1.8em';
    ta.style.boxSizing = 'border-box';
    ta.style.border = '0';
    ta.style.padding = '0';
    ta.style.margin = '0';
    ta.style.outline = 'none';
    ta.style.background = 'transparent';
    ta.style.color = 'inherit';
    ta.style.font = 'inherit';
    ta.style.lineHeight = 'inherit';
    ta.style.resize = 'none';
    ta.style.whiteSpace = 'pre-wrap';
    ta.style.overflow = 'hidden';

    var savedStyles = {};
    var tag = (el.tagName || '').toUpperCase();
    // Blockquote: hide left border line during editing
    if (tag === 'BLOCKQUOTE') {
      savedStyles.borderLeft = el.style.borderLeft;
      el.style.borderLeft = 'none';
    }
    // List item: hide CSS list marker during editing
    if (tag === 'LI') {
      savedStyles.listStyle = el.style.listStyle;
      el.style.listStyle = 'none';
    }

    _ie = { el: el, ta: ta, key: key, origHtml: el.innerHTML, savedStyles: savedStyles };
    el.innerHTML = '';
    el.appendChild(ta);
    el.style.outline = '2px solid #4a90d9';
    el.style.borderRadius = '4px';
    el.style.background = 'rgba(74,144,217,0.08)';

    var _syncHeight = function() {
      ta.style.height = 'auto';
      ta.style.height = Math.max(ta.scrollHeight, 24) + 'px';
    };
    _syncHeight();
    ta.addEventListener('input', _syncHeight);

    ta.focus();
    ta.selectionStart = ta.selectionEnd = ta.value.length;
  }
  function _restoreStyles(ie) {
    ie.el.style.outline = ie.el.style.borderRadius = ie.el.style.background = '';
    if (ie.savedStyles) {
      if (ie.savedStyles.borderLeft !== undefined) ie.el.style.borderLeft = ie.savedStyles.borderLeft;
      if (ie.savedStyles.listStyle !== undefined) ie.el.style.listStyle = ie.savedStyles.listStyle;
    }
  }
  function _commitEdit(send) {
    if (!_ie) return;
    var ie = _ie; _ie = null;
    var newText = ie.ta ? ie.ta.value : '';
    if (send === false) {
      ie.el.innerHTML = ie.origHtml;
      _restoreStyles(ie);
      return;
    }

    // Optimistic UI update: avoid restoring old rendered HTML before Flutter
    // applies the markdown mutation, which would cause a visible flicker.
    ie.el.textContent = newText;
    _restoreStyles(ie);
    if (send !== false) {
      window.flutter_inappwebview.callHandler('onInPlaceEdit', ie.key, newText);
    }
  }
  document.addEventListener('focusout', function(e) {
    if (!_ie) return;
    if (e.target === _ie.ta && !_ie.el.contains(e.relatedTarget)) {
      setTimeout(_commitEdit, 50);
    }
  }, true);
  document.addEventListener('keydown', function(e) {
    if (!_ie) return;
    if (_ie.ta && (e.key === 'ArrowUp' || e.key === 'ArrowDown') && document.activeElement === _ie.ta) {
      // Keep native textarea caret movement, but prevent Android WebView page-scroll animation.
      e.stopPropagation();
      return;
    }
    if (e.key === 'Escape') {
      _ie.el.innerHTML = _ie.origHtml;
      var s = _ie; _ie = null;
      _restoreStyles(s);
      e.preventDefault();
    } else if ((e.key === 'Enter' && (e.metaKey || e.ctrlKey)) || e.key === 'Tab') {
      e.preventDefault(); _commitEdit(true);
    }
  });
  document.addEventListener('keyup', function(e) {
    if (!_ie || !_ie.ta) return;
    if ((e.key === 'ArrowUp' || e.key === 'ArrowDown') && document.activeElement === _ie.ta) {
      e.stopPropagation();
    }
  });

  // ── Single-tap edit handler ───────────────────────────────────────────
  function _handleEditTap(target) {
    if (!target) return;
    var check = target;
    while (check && check !== document.body) {
      var tag = (check.tagName || '').toUpperCase();
      if (tag==='A'||tag==='IMG'||tag==='INPUT'||tag==='BUTTON'||tag==='VIDEO'||tag==='AUDIO'||tag==='TEXTAREA') return;
      check = check.parentElement || check.parentNode;
    }
    // Table cell?
    var node = target;
    while (node && node !== document.body) {
      var ntag = (node.tagName || '').toUpperCase();
      if (ntag === 'TD' || ntag === 'TH') {
        var table = node;
        while (table && (table.tagName||'').toUpperCase() !== 'TABLE') table = table.parentElement;
        var ti = Array.from(document.querySelectorAll('table')).indexOf(table);
        var row = node.parentElement || node.parentNode;
        var ri = Array.from(table.querySelectorAll('tr')).indexOf(row);
        var ci = Array.from(row.querySelectorAll('td,th')).indexOf(node);
        _startEdit(node, 'cell:'+ti+':'+ri+':'+ci, _getCellMd(ti,ri,ci)||node.textContent.trim());
        return;
      }
      node = node.parentElement || node.parentNode;
    }
    // Blockquote: edit the whole quote block (outermost ancestor) no matter where user taps inside.
    var qNode = target;
    var outerBq = null;
    while (qNode && qNode !== document.body) {
      if ((qNode.tagName || '').toUpperCase() === 'BLOCKQUOTE') outerBq = qNode;
      qNode = qNode.parentElement || qNode.parentNode;
    }
    if (outerBq) {
      var qMd = (outerBq.dataset && outerBq.dataset.mdSrc) || (outerBq.innerText||outerBq.textContent||'').trim();
      var qIndex = outerBq.dataset && outerBq.dataset.mdBlockIndex ? parseInt(outerBq.dataset.mdBlockIndex, 10) : -1;
      if (!qMd) {
        var qMatch = _findBlockMatch((outerBq.innerText||outerBq.textContent||'').trim());
        qMd = qMatch.md;
        qIndex = qMatch.index;
      }
      var qKey = 'blocksrc:' + btoa(unescape(encodeURIComponent(qMd))) + ':' + qIndex;
      _startEdit(outerBq, qKey, qMd);
      return;
    }

    // Other block elements
    var blockTags = ['P','H1','H2','H3','H4','H5','H6','LI','PRE'];
    var el = target;
    while (el && el !== document.body && blockTags.indexOf((el.tagName||'').toUpperCase()) === -1) {
      el = el.parentElement || el.parentNode;
    }
    if (!el || el === document.body) return;
    var blockMd = (el.dataset && el.dataset.mdSrc) || (el.innerText||el.textContent||'').trim();
    var blockIndex = el.dataset && el.dataset.mdBlockIndex ? parseInt(el.dataset.mdBlockIndex, 10) : -1;
    if (!blockMd) {
      var blockMatch = _findBlockMatch((el.innerText||el.textContent||'').trim());
      blockMd = blockMatch.md;
      blockIndex = blockMatch.index;
    }
    var blockKey = 'blocksrc:' + btoa(unescape(encodeURIComponent(blockMd))) + ':' + blockIndex;
    _startEdit(el, blockKey, blockMd);
  }

  // ── GitHub Alerts ─────────────────────────────────────────────────────
  var alertMap = {
    'NOTE':      {cls:'gh-alert-note',      icon:'ℹ️', label:'Note'},
    'TIP':       {cls:'gh-alert-tip',       icon:'💡', label:'Tip'},
    'IMPORTANT': {cls:'gh-alert-important', icon:'⭐', label:'Important'},
    'WARNING':   {cls:'gh-alert-warning',   icon:'⚠️', label:'Warning'},
    'CAUTION':   {cls:'gh-alert-caution',   icon:'🔴', label:'Caution'}
  };
  document.querySelectorAll('blockquote').forEach(function(bq){
    var txt = bq.innerText || '';
    _setBlockSource(bq, txt.trim());
    var m = txt.match(/^\\s*\\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\\]/i);
    if(m){
      var cfg = alertMap[m[1].toUpperCase()];
      if(cfg){
        var content = txt.replace(/^\\s*\\[!\\w+\\]\\s*\\n?/, '').trim();
        bq.className = 'gh-alert ' + cfg.cls;
        bq.innerHTML =
          '<div class="gh-alert-title">'+cfg.icon+' '+cfg.label+'</div>'+
          '<div>'+content.replace(/\\n/g,'<br>')+'</div>';
      }
    }
  });
  document.querySelectorAll('pre').forEach(function(pre){
    _setBlockSource(pre, (pre.innerText || pre.textContent || '').trim());
  });

  // ── Unified click handler (links + checkboxes + double-tap edit) ─────
  function _editableTapKey(target) {
    if (!target) return null;
    var node = target;
    while (node && node !== document.body) {
      var tag = (node.tagName || '').toUpperCase();
      if (tag === 'TD' || tag === 'TH') {
        var row = node.parentElement || node.parentNode;
        var table = node;
        while (table && (table.tagName||'').toUpperCase() !== 'TABLE') table = table.parentElement;
        if (!table || !row) return 'cell';
        var ti = Array.from(document.querySelectorAll('table')).indexOf(table);
        var ri = Array.from(table.querySelectorAll('tr')).indexOf(row);
        var ci = Array.from(row.querySelectorAll('td,th')).indexOf(node);
        return 'cell:' + ti + ':' + ri + ':' + ci;
      }
      if (tag === 'BLOCKQUOTE') return 'bq:' + ((node.innerText || node.textContent || '').trim().slice(0, 120));
      if (['P','H1','H2','H3','H4','H5','H6','LI','PRE'].indexOf(tag) !== -1) {
        return tag + ':' + ((node.innerText || node.textContent || '').trim().slice(0, 120));
      }
      node = node.parentElement || node.parentNode;
    }
    return null;
  }

  var _lastEditableTapTs = 0;
  var _lastEditableTapKey = null;
  document.addEventListener('click', function(e) {
    var t = e.target;
    // Link: walk up to A ancestor
    var lnk = t;
    while (lnk && lnk !== document.body && (lnk.tagName||'').toUpperCase() !== 'A') lnk = lnk.parentElement;
    if (lnk && (lnk.tagName||'').toUpperCase() === 'A') {
      e.preventDefault();
      window.flutter_inappwebview.callHandler('onLinkTap', lnk.textContent, lnk.getAttribute('href')||'', '');
      return;
    }
    // Checkbox
    if ((t.tagName||'').toUpperCase() === 'INPUT' && t.type === 'checkbox') {
      var boxes = document.querySelectorAll('input[type="checkbox"]');
      window.flutter_inappwebview.callHandler('onCheckboxChange', Array.from(boxes).indexOf(t), t.checked);
      return;
    }

    // In edit mode: keep editing when clicking inside textarea, otherwise commit and stop.
    if (_ie) {
      if (_ie.el.contains(t)) return;
      _commitEdit(true);
      return;
    }

    var tapKey = _editableTapKey(t);
    if (!tapKey) return;
    var now = Date.now();
    var isSameTarget = _lastEditableTapKey === tapKey;
    if (isSameTarget && (now - _lastEditableTapTs) <= 350) {
      _lastEditableTapTs = 0;
      _lastEditableTapKey = null;
      _handleEditTap(t);
      return;
    }

    _lastEditableTapTs = now;
    _lastEditableTapKey = tapKey;
  });
})();
</script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final html = _buildHtml();
    final baseUrl = _makeBaseUrl();

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: baseUrl,
      ),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccess: true,
        supportZoom: false,
        builtInZoomControls: false,
        displayZoomControls: false,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _webViewReady = true;
        widget.controller?._attach(controller);
        widget.controller?._attachState(this);

        // Trigger a reload now that the WebView is ready (fonts may already be
        // extracted); if not yet extracted, _triggerFontReload will be called
        // from _ensureFontsExtracted when extraction completes.
        _triggerFontReload();

        // Link tap handler
        controller.addJavaScriptHandler(
          handlerName: 'onLinkTap',
          callback: (args) {
            if (args.length >= 2) {
              widget.onTapLink?.call(
                args[0].toString(),
                args[1].toString().isEmpty ? null : args[1].toString(),
                args.length > 2 ? args[2].toString() : '',
              );
            }
            return null;
          },
        );

        // Checkbox change handler
        controller.addJavaScriptHandler(
          handlerName: 'onCheckboxChange',
          callback: (args) {
            if (args.length >= 2) {
              final index = int.tryParse(args[0].toString()) ?? 0;
              final checked = args[1] == true;
              widget.onCheckboxChanged(index, checked);
            }
            return null;
          },
        );

        // getMarkdown – JS requests raw markdown source for in-place editing
        controller.addJavaScriptHandler(
          handlerName: 'getMarkdown',
          callback: (args) {
            if (args.isEmpty) return '';
            final type = args[0].toString();
            final p1 = int.tryParse(args[1].toString()) ?? 0;
            final p2 = int.tryParse(args[2].toString()) ?? 0;
            final p3 = int.tryParse(args[3].toString()) ?? 0;
            final extra = args.length > 4 ? args[4].toString() : '';
            return widget.onGetMarkdown?.call(type, p1, p2, p3, extra) ?? '';
          },
        );

        // onInPlaceEdit – user finished in-place edit
        controller.addJavaScriptHandler(
          handlerName: 'onInPlaceEdit',
          callback: (args) {
            if (args.length >= 2) {
              widget.onInPlaceEdit?.call(args[0].toString(), args[1].toString());
            }
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        // Restore scroll position after page reload
        if (_savedScrollY > 0) {
          await controller.evaluateJavascript(
              source: 'window.scrollTo(0, $_savedScrollY)');
          _savedScrollY = 0;
        }
        widget.onLoadFinished?.call();
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.CANCEL;
      },
    );
  }
}
