import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown/markdown.dart' as md;

/// Controller for the WebView-based markdown preview.
///
/// Exposes [scrollToHeading] to navigate to a heading by its sequential index
/// in the rendered document.
class MarkdownWebViewController {
  InAppWebViewController? _webViewController;

  void _attach(InAppWebViewController controller) {
    _webViewController = controller;
  }

  /// Scroll to heading number [headingIndex] (0-based, in document order).
  ///
  /// [topOffset] pixels are scrolled back from the heading to leave a gap
  /// at the top of the viewport (default 32 px, matching [_jumpTopOffset]).
  /// The heading is also briefly flashed to indicate the navigation target.
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
  final String? baseDirectory;
  final void Function(String text, String? href, String title)? onTapLink;
  final Function(int index, bool value) onCheckboxChanged;
  final MarkdownWebViewController? controller;

  const WebViewMarkdownPreview({
    super.key,
    required this.data,
    required this.isDark,
    required this.fontSize,
    this.fontFamily,
    this.baseDirectory,
    this.onTapLink,
    required this.onCheckboxChanged,
    this.controller,
  });

  @override
  State<WebViewMarkdownPreview> createState() =>
      _WebViewMarkdownPreviewState();
}

class _WebViewMarkdownPreviewState extends State<WebViewMarkdownPreview> {
  InAppWebViewController? _webViewController;
  Timer? _debounceTimer;

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
        oldWidget.fontFamily != widget.fontFamily) {
      // Debounce to avoid reloading on every keystroke in split mode
      _debounceTimer?.cancel();
      _debounceTimer =
          Timer(const Duration(milliseconds: 300), _loadContent);
    }
  }

  void _loadContent() {
    if (_webViewController == null) return;
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
    // 1. Markdown → HTML (GitHub Flavoured Markdown)
    final htmlBody = md.markdownToHtml(
      widget.data,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    // 2. Add sequential id="heading-N" to every heading tag for TOC navigation
    int headingIdx = 0;
    final withIds = htmlBody.replaceAllMapped(
      RegExp(r'<(h[1-6])(\s[^>]*)?>'),
      (m) {
        final tag = m.group(1)!;
        final attrs = m.group(2) ?? '';
        return '<$tag id="heading-${headingIdx++}"$attrs>';
      },
    );

    // 3. Make task-list checkboxes interactive (remove the `disabled` attr)
    final interactive = withIds.replaceAll(
      RegExp(r'<input\s+type="checkbox"\s+disabled'),
      '<input type="checkbox"',
    );

    return _wrapHtml(interactive);
  }

  /// Wrap [body] in a full HTML document with inline CSS and JS.
  String _wrapHtml(String body) {
    final dark = widget.isDark;
    final fs = widget.fontSize;
    final ff = widget.fontFamily;

    // ── Colour palette ────────────────────────────────────────────────────
    final bg = dark ? '#1a1a2e' : '#ffffff';
    final fg = dark ? '#e0e0e0' : '#1a1a1a';
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
    const monoFont =
        'JetBrains Mono, Consolas, Monaco, "Courier New", monospace';

    // ── Heading flash animation ───────────────────────────────────────────
    final flashKf = dark
        ? '@keyframes hflash { 0%{background:transparent} 20%{background:rgba(100,180,255,0.35)} 100%{background:transparent} }'
        : '@keyframes hflash { 0%{background:transparent} 20%{background:rgba(0,122,255,0.25)} 100%{background:transparent} }';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=yes">
<style>
*{box-sizing:border-box}
body{background:$bg;color:$fg;font-family:$bodyFont;font-size:${fs}px;line-height:1.6;padding:16px;margin:0;word-wrap:break-word;overflow-wrap:break-word}
h1,h2,h3,h4,h5,h6{color:$hColor;font-weight:bold;line-height:1.4;margin:1em 0 0.5em;border-radius:4px}
h1{font-size:${fs * 2}px;border-bottom:2px solid $hrColor;padding-bottom:0.3em}
h2{font-size:${fs * 1.5}px;border-bottom:1px solid $hrColor;padding-bottom:0.2em}
h3{font-size:${fs * 1.25}px}h4{font-size:${fs * 1.1}px}h5{font-size:${fs}px}h6{font-size:${fs * 0.9}px}
$flashKf
.heading-flash{animation:hflash 0.7s ease-out forwards}
p{margin:0.8em 0}
a{color:$linkColor;text-decoration:none}a:hover{text-decoration:underline}
code{background:$codeBg;color:$codeColor;font-family:$monoFont;font-size:${fs * 0.9}px;padding:2px 6px;border-radius:4px}
pre{background:$codeBlockBg;border:1px solid $codeBlockBorder;border-radius:8px;padding:16px;overflow-x:auto;margin:1em 0}
pre code{background:none;color:$codeColor;padding:0;border-radius:0;font-size:${fs * 0.85}px;line-height:1.5}
blockquote{border-left:4px solid $bqBorder;background:$bqBg;margin:1em 0;padding:8px 8px 8px 16px;border-radius:0 4px 4px 0}
blockquote p{margin:0}
table{border-collapse:collapse;width:100%;margin:1em 0;border-radius:6px;overflow:hidden}
th,td{border:1px solid $tblBorder;padding:8px 12px;text-align:left}
th{background:$tblHeadBg;font-weight:bold}
img{max-width:100%;height:auto;display:block;margin:0.5em auto;border-radius:4px}
ul,ol{padding-left:1.5em;margin:0.5em 0}li{margin:0.3em 0}
input[type="checkbox"]{margin-right:6px}
hr{border:none;border-top:1px solid $hrColor;margin:1.5em 0}
del{color:$delColor}
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
  // ── Link handler ────────────────────────────────────────────────────────
  document.addEventListener('click', function(e){
    var t = e.target;
    while(t && t.tagName !== 'A') t = t.parentNode;
    if(t && t.tagName === 'A'){
      e.preventDefault();
      var href = t.getAttribute('href') || '';
      var text = t.textContent || '';
      window.flutter_inappwebview.callHandler('onLinkTap', text, href, '');
    }
  });

  // ── Checkbox handler ─────────────────────────────────────────────────
  document.addEventListener('change', function(e){
    if(e.target.tagName === 'INPUT' && e.target.type === 'checkbox'){
      var boxes = document.querySelectorAll('input[type="checkbox"]');
      var idx = Array.from(boxes).indexOf(e.target);
      window.flutter_inappwebview.callHandler('onCheckboxChange', idx, e.target.checked);
    }
  });

  // ── GitHub Alerts ────────────────────────────────────────────────────
  var alertMap = {
    'NOTE':      {cls:'gh-alert-note',      icon:'ℹ️', label:'Note'},
    'TIP':       {cls:'gh-alert-tip',       icon:'💡', label:'Tip'},
    'IMPORTANT': {cls:'gh-alert-important', icon:'⭐', label:'Important'},
    'WARNING':   {cls:'gh-alert-warning',   icon:'⚠️', label:'Warning'},
    'CAUTION':   {cls:'gh-alert-caution',   icon:'🔴', label:'Caution'}
  };
  document.querySelectorAll('blockquote').forEach(function(bq){
    var txt = bq.innerText || '';
    var m = txt.match(/^\\s*\\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\\]/i);
    if(m){
      var cfg = alertMap[m[1].toUpperCase()];
      if(cfg){
        var content = txt.replace(/^\\s*\\[!\\w+\\]\\s*\\n?/, '').trim();
        bq.className = 'gh-alert ' + cfg.cls;
        bq.innerHTML =
          '<div class="gh-alert-title">' + cfg.icon + ' ' + cfg.label + '</div>' +
          '<div>' + content.replace(/\\n/g,'<br>') + '</div>';
      }
    }
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
        supportZoom: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        widget.controller?._attach(controller);

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
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        // All navigation is handled by the link tap JS handler above
        return NavigationActionPolicy.CANCEL;
      },
    );
  }
}
