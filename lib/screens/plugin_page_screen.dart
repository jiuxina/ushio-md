import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../plugins/extensions/navigation_extension.dart';
import '../plugins/plugin_loader.dart';

/// A screen that renders the content page registered by a plugin.
///
/// Supports three content types:
/// - [NavigationContentType.webview] – loads a local HTML file in an
///   InAppWebView.
/// - [NavigationContentType.markdown] – reads the markdown file and renders
///   it in an InAppWebView.
/// - [NavigationContentType.list] – falls back to the same webview/markdown
///   approach based on the file extension.
class PluginPageScreen extends StatefulWidget {
  final PluginNavigationExtension extension;

  const PluginPageScreen({super.key, required this.extension});

  @override
  State<PluginPageScreen> createState() => _PluginPageScreenState();
}

class _PluginPageScreenState extends State<PluginPageScreen> {
  bool _loading = true;
  String? _errorMessage;

  // For webview content
  String? _filePath;

  // For markdown/fallback content
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final pluginsDir = await PluginLoader.getPluginsDirectory();
      final pluginDir =
          Directory('${pluginsDir.path}/${widget.extension.pluginId}');

      if (!pluginDir.existsSync()) {
        setState(() {
          _errorMessage = '插件目录不存在';
          _loading = false;
        });
        return;
      }

      final contentPath = widget.extension.contentPath;

      if (contentPath == null || contentPath.isEmpty) {
        setState(() {
          _errorMessage = '插件未提供内容路径';
          _loading = false;
        });
        return;
      }

      final file = File('${pluginDir.path}/$contentPath');

      if (!file.existsSync()) {
        setState(() {
          _errorMessage = '插件内容文件不存在: $contentPath';
          _loading = false;
        });
        return;
      }

      final type = widget.extension.contentType;
      final ext = contentPath.split('.').last.toLowerCase();

      if (type == NavigationContentType.webview ||
          ext == 'html' ||
          ext == 'htm') {
        // Load HTML file directly
        setState(() {
          _filePath = file.path;
          _loading = false;
        });
      } else {
        // Markdown or other text – render as HTML
        final raw = await file.readAsString();
        final htmlBody = _markdownToSimpleHtml(raw);
        setState(() {
          _htmlContent = htmlBody;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _loading = false;
      });
    }
  }

  /// Very simple Markdown-to-HTML conversion for plugin pages.
  String _markdownToSimpleHtml(String md) {
    final lines = md.split('\n');
    final buf = StringBuffer();
    buf.write('<html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>body{font-family:sans-serif;padding:16px;line-height:1.6}'
        'pre{background:#f4f4f4;padding:8px;border-radius:4px;overflow-x:auto}'
        'code{font-family:monospace}</style></head><body>');
    bool inCode = false;
    bool inList = false;
    for (final line in lines) {
      if (line.trim().startsWith('```')) {
        if (inCode) {
          buf.write('</code></pre>');
        } else {
          if (inList) {
            buf.write('</ul>');
            inList = false;
          }
          buf.write('<pre><code>');
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        buf.write('${_escapeHtml(line)}\n');
        continue;
      }
      final isList = line.startsWith('- ') || line.startsWith('* ');
      if (!isList && inList) {
        buf.write('</ul>');
        inList = false;
      }
      if (line.startsWith('# ')) {
        buf.write('<h1>${_escapeHtml(line.substring(2))}</h1>');
      } else if (line.startsWith('## ')) {
        buf.write('<h2>${_escapeHtml(line.substring(3))}</h2>');
      } else if (line.startsWith('### ')) {
        buf.write('<h3>${_escapeHtml(line.substring(4))}</h3>');
      } else if (isList) {
        if (!inList) {
          buf.write('<ul>');
          inList = true;
        }
        buf.write('<li>${_escapeHtml(line.substring(2))}</li>');
      } else if (line.trim().isEmpty) {
        buf.write('<br>');
      } else {
        buf.write('<p>${_escapeHtml(line)}</p>');
      }
    }
    if (inList) buf.write('</ul>');
    if (inCode) buf.write('</code></pre>');
    buf.write('</body></html>');
    return buf.toString();
  }

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.extension.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_filePath != null) {
      // Load local HTML file
      return InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri.uri(Uri.file(_filePath!)),
        ),
        initialSettings: InAppWebViewSettings(
          allowFileAccess: true,
          allowFileAccessFromFileURLs: true,
          javaScriptEnabled: true,
        ),
      );
    }

    // Render HTML string (markdown converted)
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: _htmlContent ?? '',
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
      ),
    );
  }
}
