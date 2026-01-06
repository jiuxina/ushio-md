// ============================================================================
// MarkdownFile 模型测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/models/markdown_file.dart';

void main() {
  group('MarkdownFile', () {
    test('属性初始化正确', () {
      final now = DateTime.now();
      final file = MarkdownFile(
        path: '/path/to/test.md',
        name: 'test.md',
        lastModified: now,
        size: 1024,
      );
      
      expect(file.path, '/path/to/test.md');
      expect(file.name, 'test.md');
      expect(file.lastModified, now);
      expect(file.size, 1024);
      expect(file.content, '');
    });

    test('displayName 应移除扩展名', () {
      final file = MarkdownFile(
        path: '/path/to/test.md',
        name: 'test.md',
        lastModified: DateTime.now(),
        size: 1024,
      );
      
      expect(file.displayName, 'test');
    });

    test('formattedSize 应格式化大小', () {
      final file = MarkdownFile(
        path: 'p', name: 'n', lastModified: DateTime.now(),
        size: 512,
      );
      expect(file.formattedSize, '512 B');
      
      final fileKB = MarkdownFile(
        path: 'p', name: 'n', lastModified: DateTime.now(),
        size: 2048,
      );
      expect(fileKB.formattedSize, '2.0 KB');
    });
  });
}
