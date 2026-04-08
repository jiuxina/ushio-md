// ============================================================================
// 内容安全工具测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_ContentSanitizer.sanitizeMarkdown', () {
    late _ContentSanitizer sanitizer;
    
    setUp(() {
      sanitizer = _ContentSanitizer();
    });

    test('保留正常的 Markdown 内容', () {
      const markdown = '''
# 标题

这是一段正常的文本。

- 列表项 1
- 列表项 2

[链接](https://example.com)

![图片](https://example.com/image.png)

```dart
print('Hello');
```
''';
      final result = sanitizer.sanitizeMarkdown(markdown);
      expect(result, equals(markdown));
    });

    test('移除 script 标签', () {
      const markdown = 'Hello\n<script>alert("XSS")</script>\nWorld';
      final result = sanitizer.sanitizeMarkdown(markdown);
      expect(result, isNot(contains('<script>')));
      expect(result, contains('Hello'));
      expect(result, contains('World'));
    });

    test('移除 iframe 标签', () {
      const markdown = '<iframe src="evil.com"></iframe>Normal text';
      final result = sanitizer.sanitizeMarkdown(markdown);
      expect(result, isNot(contains('<iframe')));
    });

    test('移除事件处理器', () {
      const markdown = '<img src="x" onerror="alert(1)">';
      final result = sanitizer.sanitizeMarkdown(markdown);
      expect(result, isNot(contains('onerror')));
    });

    test('移除 onclick 属性', () {
      const markdown = '<a href="#" onclick="evil()">Click</a>';
      final result = sanitizer.sanitizeMarkdown(markdown);
      expect(result, isNot(contains('onclick')));
    });

    test('处理多个危险标签', () {
      const markdown = '''
<script>alert(1)</script>
<object data="evil.swf"></object>
<embed src="evil.swf">
Normal text
''';
      final result = sanitizer.sanitizeMarkdown(markdown);
      expect(result, isNot(contains('<script')));
      expect(result, isNot(contains('<object')));
      expect(result, isNot(contains('<embed')));
      expect(result, contains('Normal text'));
    });
  });

  group('_ContentSanitizer.sanitizeUrl', () {
    late _ContentSanitizer sanitizer;
    
    setUp(() {
      sanitizer = _ContentSanitizer();
    });

    test('允许 http/https URL', () {
      expect(sanitizer.sanitizeUrl('https://example.com'), equals('https://example.com'));
      expect(sanitizer.sanitizeUrl('http://example.com'), equals('http://example.com'));
    });

    test('允许 mailto/tel 协议', () {
      expect(sanitizer.sanitizeUrl('mailto:test@example.com'), equals('mailto:test@example.com'));
      expect(sanitizer.sanitizeUrl('tel:+1234567890'), equals('tel:+1234567890'));
    });

    test('允许相对路径', () {
      expect(sanitizer.sanitizeUrl('/path/to/file'), equals('/path/to/file'));
      expect(sanitizer.sanitizeUrl('#anchor'), equals('#anchor'));
      expect(sanitizer.sanitizeUrl('?query=1'), equals('?query=1'));
    });

    test('允许 data:image URI', () {
      expect(
        sanitizer.sanitizeUrl('data:image/png;base64,abc'),
        equals('data:image/png;base64,abc'),
      );
      expect(
        sanitizer.sanitizeUrl('data:image/svg+xml,<svg></svg>'),
        equals('data:image/svg+xml,<svg></svg>'),
      );
    });

    test('阻止 javascript: 协议', () {
      expect(
        sanitizer.sanitizeUrl('javascript:alert(1)'),
        equals('#blocked'),
      );
      expect(
        sanitizer.sanitizeUrl('JAVASCRIPT:alert(1)'),
        equals('#blocked'),
      );
    });

    test('阻止 vbscript: 协议', () {
      expect(
        sanitizer.sanitizeUrl('vbscript:msgbox(1)'),
        equals('#blocked'),
      );
    });

    test('阻止危险的 data: URI', () {
      expect(
        sanitizer.sanitizeUrl('data:text/html,<script>alert(1)</script>'),
        equals('#blocked'),
      );
    });
  });

  group('_ContentSanitizer.containsDangerousContent', () {
    late _ContentSanitizer sanitizer;
    
    setUp(() {
      sanitizer = _ContentSanitizer();
    });

    test('检测正常内容为安全', () {
      expect(sanitizer.containsDangerousContent('# Hello\n\nWorld'), isFalse);
      expect(sanitizer.containsDangerousContent('[link](https://example.com)'), isFalse);
    });

    test('检测 script 标签', () {
      expect(sanitizer.containsDangerousContent('<script>alert(1)</script>'), isTrue);
    });

    test('检测事件处理器', () {
      expect(sanitizer.containsDangerousContent('<img onerror="x">'), isTrue);
      expect(sanitizer.containsDangerousContent('<div onclick="x">'), isTrue);
    });

    test('检测 javascript: 协议', () {
      expect(sanitizer.containsDangerousContent('href="javascript:x"'), isTrue);
    });
  });
}

/// 测试用的内容清理器实现
class _ContentSanitizer {
  static final RegExp _dangerousTags = RegExp(
    r'<\s*(script|iframe|object|embed|form|input|button|meta|link|style|base)[^>]*>',
    caseSensitive: false,
  );
  
  static final RegExp _dangerousAttributes = RegExp(
    r'\s(on\w+)\s*=\s*["\'][^"\']*["\']',
    caseSensitive: false,
  );
  
  static final RegExp _javascriptProtocol = RegExp(
    r'(href|src|action)\s*=\s*["\']?\s*javascript:',
    caseSensitive: false,
  );
  
  String sanitizeMarkdown(String markdown) {
    var sanitized = markdown;
    sanitized = sanitized.replaceAll(_dangerousTags, '');
    sanitized = sanitized.replaceAllMapped(_dangerousAttributes, (m) => '');
    sanitized = sanitized.replaceAllMapped(
      _javascriptProtocol,
      (m) => m.group(0)!.replaceFirst(RegExp(r'javascript:', caseSensitive: false), '#'),
    );
    return sanitized;
  }
  
  String sanitizeUrl(String url) {
    final trimmed = url.trim();
    const allowedProtocols = ['http://', 'https://', 'ftp://', 'mailto:', 'tel:'];
    
    for (final proto in allowedProtocols) {
      if (trimmed.toLowerCase().startsWith(proto)) return trimmed;
    }
    
    if (trimmed.startsWith('/') || trimmed.startsWith('#') || trimmed.startsWith('?')) {
      return trimmed;
    }
    
    if (trimmed.toLowerCase().startsWith('data:image/')) return trimmed;
    
    if (trimmed.toLowerCase().startsWith('javascript:') ||
        trimmed.toLowerCase().startsWith('vbscript:') ||
        trimmed.toLowerCase().startsWith('data:text/html')) {
      return '#blocked';
    }
    
    return trimmed;
  }
  
  bool containsDangerousContent(String content) {
    return _dangerousTags.hasMatch(content) ||
           _dangerousAttributes.hasMatch(content) ||
           _javascriptProtocol.hasMatch(content);
  }
}
