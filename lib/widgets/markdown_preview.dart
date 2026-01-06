import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:markdown/markdown.dart' as md;
import '../providers/settings_provider.dart';

class MarkdownPreview extends StatelessWidget {
  final String data;

  final SettingsProvider settings;
  final ScrollController? controller;
  final Function(int, bool) onCheckboxChanged;
  /// Base directory for resolving relative image paths
  final String? baseDirectory;

  const MarkdownPreview({
    super.key,
    required this.data,

    required this.settings,
    this.controller,
    required this.onCheckboxChanged,
    this.baseDirectory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int checkboxIndex = 0;

    return Markdown(
      controller: controller,
      data: data,

      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: settings.fontSize, 
          height: 1.6,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        h1: TextStyle(
          fontSize: settings.fontSize * 2,
          fontWeight: FontWeight.bold,
          height: 1.4,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        h2: TextStyle(
          fontSize: settings.fontSize * 1.5,
          fontWeight: FontWeight.bold,
          height: 1.4,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        h3: TextStyle(
          fontSize: settings.fontSize * 1.25,
          fontWeight: FontWeight.w600,
          height: 1.4,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        h4: TextStyle(
          fontSize: settings.fontSize * 1.1,
          fontWeight: FontWeight.w600,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        h5: TextStyle(
          fontSize: settings.fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        h6: TextStyle(
          fontSize: settings.fontSize * 0.9,
          fontWeight: FontWeight.w600,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        code: TextStyle(
          backgroundColor: isDark 
              ? const Color(0xFF2d2d2d) 
              : const Color(0xFFf5f5f5),
          fontFamily: settings.codeFontFamily == 'System' ? 'monospace' : settings.codeFontFamily,
          fontSize: settings.fontSize * 0.9,
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
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
          ),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        listBullet: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: settings.fontSize,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        tableBody: TextStyle(
          fontSize: settings.fontSize,
          fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
        ),
        tableBorder: TableBorder.all(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(8),
        ),
        tableCellsPadding: const EdgeInsets.all(8),
        tableHeadAlign: TextAlign.center,
      ),
      builders: {
        'code': CodeBlockBuilder(
          isDark: isDark, 
          fontSize: settings.fontSize,
          fontFamily: settings.codeFontFamily == 'System' ? null : settings.codeFontFamily,
        ),
      },
      checkboxBuilder: (bool value) {
        final currentIndex = checkboxIndex++;
        return Checkbox(
          value: value,
          onChanged: (newValue) {
            onCheckboxChanged(currentIndex, newValue ?? false);
            checkboxIndex = 0; // Reset logic might needed depending on rebuild
          },
          activeColor: Theme.of(context).colorScheme.primary,
        );
      },
      imageBuilder: (uri, title, alt) => _buildImage(uri, title, alt),
    );
  }

  /// Build image widget with support for local and relative paths
  Widget _buildImage(Uri uri, String? title, String? alt) {
    String imagePath = uri.toString();
    
    // Handle relative paths
    if (baseDirectory != null && !imagePath.startsWith('http') && !imagePath.startsWith('file://')) {
      // Convert relative path to absolute
      imagePath = '$baseDirectory${Platform.pathSeparator}${imagePath.replaceAll('/', Platform.pathSeparator)}';
    }
    
    // Handle file:// URI
    if (imagePath.startsWith('file://')) {
      imagePath = imagePath.substring(7);
    }
    
    // Check if it's a local file
    if (!imagePath.startsWith('http')) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
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
                  Text(alt ?? '图片加载失败', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          },
        );
      } else {
        // File doesn't exist
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
    }
    
    // Network image
    return Image.network(
      imagePath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
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
              Text(alt ?? '网络图片加载失败', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
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
