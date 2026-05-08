import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:markdown/markdown.dart' as md;
import '../providers/settings_provider.dart';

class MarkdownPreview extends StatefulWidget {
  final String data;

  final SettingsProvider settings;
  final ScrollController? controller;
  final Function(int, bool) onCheckboxChanged;
  /// Base directory for resolving relative image paths
  final String? baseDirectory;
  /// Callback when a link is tapped
  final void Function(String text, String? href, String title)? onTapLink;
  /// If true, use MarkdownBody (non-scrollable) instead of Markdown (scrollable)
  final bool shrinkWrap;
  /// Anchor keys for headings: maps heading text to GlobalKey for scroll position measurement
  final Map<String, GlobalKey>? headingAnchorKeys;

  const MarkdownPreview({
    super.key,
    required this.data,

    required this.settings,
    this.controller,
    required this.onCheckboxChanged,
    this.baseDirectory,
    this.onTapLink,
    this.shrinkWrap = false,
    this.headingAnchorKeys,
  });

  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  MarkdownStyleSheet? _cachedStyleSheet;
  Brightness? _cachedBrightness;
  String? _cachedFontFamily;
  double? _cachedFontSize;
  String? _cachedCodeFontFamily;
  Color? _cachedPrimaryColor;
  Color? _cachedDividerColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyleSheetIfNeeded();
  }

  @override
  void didUpdateWidget(MarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateStyleSheetIfNeeded();
  }

  void _updateStyleSheetIfNeeded() {
    final theme = Theme.of(context);
    final isDark = theme.brightness;
    final fontFamily = widget.settings.editorFontFamily == 'System'
        ? null
        : widget.settings.editorFontFamily;
    final fontSize = widget.settings.fontSize;
    final codeFontFamily = widget.settings.codeFontFamily == 'System' ? 'monospace' : widget.settings.codeFontFamily;
    final primaryColor = theme.colorScheme.primary;
    final dividerColor = theme.dividerColor;

    // Check if any relevant property changed
    if (_cachedBrightness != isDark ||
        _cachedFontFamily != fontFamily ||
        _cachedFontSize != fontSize ||
        _cachedCodeFontFamily != codeFontFamily ||
        _cachedPrimaryColor != primaryColor ||
        _cachedDividerColor != dividerColor) {
      // Update cache keys
      _cachedBrightness = isDark;
      _cachedFontFamily = fontFamily;
      _cachedFontSize = fontSize;
      _cachedCodeFontFamily = codeFontFamily;
      _cachedPrimaryColor = primaryColor;
      _cachedDividerColor = dividerColor;

      // Rebuild stylesheet
      _cachedStyleSheet = _buildStyleSheet(
        isDark: isDark == Brightness.dark,
        fontFamily: fontFamily,
        fontSize: fontSize,
        codeFontFamily: codeFontFamily,
        primaryColor: primaryColor,
        dividerColor: dividerColor,
      );
    }
  }

  MarkdownStyleSheet _buildStyleSheet({
    required bool isDark,
    required String? fontFamily,
    required double fontSize,
    required String? codeFontFamily,
    required Color primaryColor,
    required Color dividerColor,
  }) {
    const lineHeight = 1.6;

    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: fontSize, 
        height: lineHeight,
        fontFamily: fontFamily,
      ),
      h1: TextStyle(
        fontSize: fontSize * 2,
        fontWeight: FontWeight.bold,
        height: 1.4,
        fontFamily: fontFamily,
      ),
      h2: TextStyle(
        fontSize: fontSize * 1.5,
        fontWeight: FontWeight.bold,
        height: 1.4,
        fontFamily: fontFamily,
      ),
      h3: TextStyle(
        fontSize: fontSize * 1.25,
        fontWeight: FontWeight.w600,
        height: 1.4,
        fontFamily: fontFamily,
      ),
      h4: TextStyle(
        fontSize: fontSize * 1.1,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
      ),
      h5: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
      ),
      h6: TextStyle(
        fontSize: fontSize * 0.9,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
      ),
      code: TextStyle(
        backgroundColor: isDark 
            ? const Color(0xFF2d2d2d) 
            : const Color(0xFFf5f5f5),
        fontFamily: codeFontFamily,
        fontSize: fontSize * 0.9,
        color: isDark ? const Color(0xFFe6e6e6) : const Color(0xFF333333),
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1e1e1e) 
            : const Color(0xFFf8f8f8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? const Color(0xFF3d3d3d) 
              : const Color(0xFFe0e0e0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      codeblockPadding: const EdgeInsets.all(16),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: primaryColor,
            width: 4,
          ),
        ),
        color: primaryColor.withValues(alpha: 0.05),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      listBullet: TextStyle(
        color: primaryColor,
        fontFamily: fontFamily,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: dividerColor,
            width: 1,
          ),
        ),
      ),
      tableHead: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
        fontFamily: fontFamily,
      ),
      tableBody: TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
      ),
      tableBorder: TableBorder.all(
        color: dividerColor,
        borderRadius: BorderRadius.circular(8),
      ),
      tableCellsPadding: const EdgeInsets.all(8),
      tableHeadAlign: TextAlign.center,
    );
  }

  /// Convert HTML <img> tags to markdown image syntax
  /// flutter_markdown_plus doesn't support inline HTML, so we preprocess
  static String _convertHtmlImagesToMarkdown(String data) {
    // Match <img ... src="..." ...> with any attribute order
    // Handles: src before alt, alt before src, missing alt, self-closing
    final imgTagRegex = RegExp(
      r'<img\s[^>]*?>',
      caseSensitive: false,
      dotAll: true,
    );
    return data.replaceAllMapped(imgTagRegex, (match) {
      final tag = match.group(0) ?? '';
      // Extract src attribute
      final srcMatch = RegExp(r'src\s*=\s*["\']([^"\']*)["\']', caseSensitive: false).firstMatch(tag);
      if (srcMatch == null) return tag; // No src, leave as-is
      final src = srcMatch.group(1) ?? '';
      // Extract alt attribute (optional)
      final altMatch = RegExp(r'alt\s*=\s*["\']([^"\']*)["\']', caseSensitive: false).firstMatch(tag);
      final alt = altMatch?.group(1) ?? '';
      // Escape brackets in alt text for valid markdown
      final escapedAlt = alt.replaceAll('[', '\\[').replaceAll(']', '\\]');
      return '![$escapedAlt]($src)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int checkboxIndex = 0;

    // Ensure stylesheet is available
    _updateStyleSheetIfNeeded();
    final styleSheet = _cachedStyleSheet!;

    // Preprocess: convert HTML <img> tags to markdown syntax
    final processedData = _convertHtmlImagesToMarkdown(widget.data);

    final builders = <String, MarkdownElementBuilder>{
      'code': CodeBlockBuilder(
        isDark: isDark,
        fontSize: widget.settings.fontSize,
        fontFamily: widget.settings.codeFontFamily == 'System' ? null : widget.settings.codeFontFamily,
      ),
      'blockquote': GitHubAlertBuilder(isDark: isDark, fontSize: widget.settings.fontSize),
    };

    // Add heading anchor builders when anchor keys are provided
    if (widget.headingAnchorKeys != null && widget.headingAnchorKeys!.isNotEmpty) {
      final anchorBuilder = HeadingAnchorBuilder(widget.headingAnchorKeys!);
      for (final tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']) {
        builders[tag] = anchorBuilder;
      }
    }

    Widget checkboxBuilderFn(bool value) {
      final currentIndex = checkboxIndex++;
      return Checkbox(
        value: value,
        onChanged: (newValue) {
          widget.onCheckboxChanged(currentIndex, newValue ?? false);
          checkboxIndex = 0;
        },
        activeColor: Theme.of(context).colorScheme.primary,
      );
    }

    Widget imageBuilderFn(Uri uri, String? title, String? alt) {
      return Builder(
        builder: (context) => _buildImage(context, uri, title, alt),
      );
    }

    if (widget.shrinkWrap) {
      return MarkdownBody(
        data: processedData,
        onTapLink: widget.onTapLink,
        selectable: true,
        styleSheet: styleSheet,
        builders: builders,
        checkboxBuilder: checkboxBuilderFn,
        imageBuilder: imageBuilderFn,
      );
    }

    return Markdown(
      controller: widget.controller,
      data: processedData,
      onTapLink: widget.onTapLink,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: styleSheet,
      builders: builders,
      checkboxBuilder: checkboxBuilderFn,
      imageBuilder: imageBuilderFn,
    );
  }

  /// Build image widget with support for local and relative paths
  /// Tap on image to show fullscreen preview
  Widget _buildImage(BuildContext context, Uri uri, String? title, String? alt) {
    String imagePath = uri.toString();
    
    // Handle relative paths
    if (widget.baseDirectory != null && !imagePath.startsWith('http') && !imagePath.startsWith('file://')) {
      // Convert relative path to absolute
      imagePath = '${widget.baseDirectory}${Platform.pathSeparator}${imagePath.replaceAll('/', Platform.pathSeparator)}';
    }
    
    // Handle file:// URI
    if (imagePath.startsWith('file://')) {
      imagePath = imagePath.substring(7);
    }
    
    Widget imageWidget;
    
    // Check if it's a local file
    if (!imagePath.startsWith('http')) {
      final file = File(imagePath);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageError(alt ?? '图片加载失败');
          },
        );
      } else {
        // File doesn't exist - not tappable
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported, color: Colors.orange),
              const SizedBox(width: 8),
              Text(alt ?? '图片不存在', style: const TextStyle(color: Colors.orange)),
            ],
          ),
        );
      }
    } else {
      // Network image
      imageWidget = Image.network(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageError(alt ?? '网络图片加载失败');
        },
      );
    }
    
    // Wrap in GestureDetector for fullscreen preview on tap
    return GestureDetector(
      onTap: () => _showFullscreenImage(context, imagePath, alt),
      child: imageWidget,
    );
  }

  Widget _buildImageError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  /// Show fullscreen image preview dialog
  void _showFullscreenImage(BuildContext context, String imagePath, String? alt) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: imagePath.startsWith('http')
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImageError(alt ?? '图片加载失败'),
                      )
                    : Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImageError(alt ?? '图片加载失败'),
                      ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;
  final double fontSize;
  final String? fontFamily;
  

  static const _langMap = {
    'js': 'javascript',
    'ts': 'typescript',
    'py': 'python',
    'rb': 'ruby',
    'sh': 'bash',
    'shell': 'bash',
    'yml': 'yaml',
    'md': 'markdown',
    'objc': 'objectivec',
    'c++': 'cpp',
    'c#': 'csharp',
  };

  CodeBlockBuilder({
    required this.isDark, 
    required this.fontSize,
    this.fontFamily,
  });
  
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code') return null;
    
    final code = element.textContent;
    
    String language = '';
    final className = element.attributes['class'];
    if (className != null && className.startsWith('language-')) {
      language = className.replaceFirst('language-', '');
    }
    
    if (language.isEmpty || code.length < 20) {
      return null;
    }
    
    try {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282c34) : const Color(0xFFfafafa),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF3d3d3d) : const Color(0xFFe0e0e0),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF21252b) 
                        : const Color(0xFFf0f0f0),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark 
                            ? const Color(0xFF3d3d3d) 
                            : const Color(0xFFe0e0e0),
                      ),
                    ),
                  ),
                  child: Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark 
                          ? const Color(0xFF7f848e) 
                          : const Color(0xFF6a737d),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: HighlightView(
                  code,
                  language: _mapLanguage(language),
                  theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                  textStyle: TextStyle(
                    fontFamily: fontFamily ?? 'monospace',
                    fontSize: fontSize * 0.85,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return null;
    }
  }
  
  String _mapLanguage(String lang) {
    return _langMap[lang.toLowerCase()] ?? lang.toLowerCase();
  }
}

/// GitHub 风格 Alert 渲染器
/// 
/// 支持的 Alert 类型：
/// - [!NOTE] - 信息提示（蓝色）
/// - [!TIP] - 技巧提示（绿色）
/// - [!IMPORTANT] - 重要信息（紫色）
/// - [!WARNING] - 警告信息（橙色）
/// - [!CAUTION] - 危险警告（红色）
/// 
/// 插件开发者可以通过在 Markdown 中使用 `> [!NOTE]` 等语法来触发这些样式。
class GitHubAlertBuilder extends MarkdownElementBuilder {
  final bool isDark;
  final double fontSize;
  
  /// Alert 类型配置
  /// 键: Alert 类型名称
  /// 值: (颜色, 图标, 显示标题)
  static const Map<String, (Color, IconData, String)> _alertTypes = {
    'NOTE': (Color(0xFF0969DA), Icons.info_outline, 'Note'),
    'TIP': (Color(0xFF1A7F37), Icons.tips_and_updates, 'Tip'),
    'IMPORTANT': (Color(0xFF8250DF), Icons.star_outline, 'Important'),
    'WARNING': (Color(0xFFBF8700), Icons.warning_amber_rounded, 'Warning'),
    'CAUTION': (Color(0xFFCF222E), Icons.error_outline, 'Caution'),
  };
  
  GitHubAlertBuilder({required this.isDark, required this.fontSize});
  
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'blockquote') return null;
    
    // 获取 blockquote 的文本内容
    final textContent = _extractTextContent(element);
    
    // 检测 [!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION] 模式
    final alertPattern = RegExp(r'^\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*\n?', caseSensitive: false);
    final match = alertPattern.firstMatch(textContent);
    
    if (match == null) {
      return null; // 不是 GitHub Alert，使用默认渲染
    }
    
    final alertType = match.group(1)!.toUpperCase();
    final content = textContent.substring(match.end).trim();
    
    return _buildAlertWidget(alertType, content);
  }
  
  /// 递归提取元素的文本内容
  String _extractTextContent(md.Node node) {
    if (node is md.Text) {
      return node.text;
    }
    if (node is md.Element) {
      final buffer = StringBuffer();
      for (final child in node.children ?? []) {
        buffer.write(_extractTextContent(child));
        if (child is md.Element && child.tag == 'p') {
          buffer.write('\n');
        }
      }
      return buffer.toString();
    }
    return '';
  }
  
  /// 构建 Alert Widget
  Widget _buildAlertWidget(String type, String content) {
    final config = _alertTypes[type];
    if (config == null) return Text(content);
    
    final (color, icon, title) = config;
    
    // 深色模式下调整颜色亮度
    final displayColor = isDark ? Color.lerp(color, Colors.white, 0.3)! : color;
    final bgColor = isDark 
        ? color.withValues(alpha: 0.15)
        : color.withValues(alpha: 0.1);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: displayColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert 标题行
          Row(
            children: [
              Icon(icon, color: displayColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: displayColor,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize * 0.9,
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Alert 内容
            Text(
              content,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps heading elements with their anchor GlobalKey for scroll position measurement.
///
/// Maps heading text to the corresponding [GlobalKey] so that after rendering,
/// callers can call [GlobalKey.currentContext] to measure the rendered position.
class HeadingAnchorBuilder extends MarkdownElementBuilder {
  final Map<String, GlobalKey> anchorKeys;

  HeadingAnchorBuilder(this.anchorKeys);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final headingTags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};
    if (!headingTags.contains(element.tag)) return null;

    final headingText = element.textContent.trim();
    final key = anchorKeys[headingText];
    if (key == null) return null;

    // Return heading text with anchor key for position measurement.
    // The key on this widget enables callers to find the heading's scroll position.
    return Text(
      headingText,
      key: key,
      style: preferredStyle,
    );
  }
}
