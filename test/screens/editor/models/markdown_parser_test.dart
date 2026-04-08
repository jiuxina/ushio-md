// ============================================================================
// Markdown 解析器测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:ushio_md/screens/editor/models/markdown_parser.dart';

void main() {
  group('parseMarkdownBlocks', () {
    test('parses single lines as individual blocks', () {
      const text = 'Line 1\nLine 2\nLine 3';
      final blocks = parseMarkdownBlocks(text);

      expect(blocks.length, equals(3));
      expect(blocks[0].isMultiLine, isFalse);
      expect(blocks[0].content, equals('Line 1'));
      expect(blocks[1].content, equals('Line 2'));
      expect(blocks[2].content, equals('Line 3'));
    });

    test('parses code blocks as multi-line blocks', () {
      const text = '''
```dart
void main() {
  print('Hello');
}
```
Some text after''';

      final blocks = parseMarkdownBlocks(text);

      expect(blocks.length, equals(2));
      expect(blocks[0].isMultiLine, isTrue);
      expect(blocks[0].content, contains('```dart'));
      expect(blocks[0].content, contains('print'));
      expect(blocks[1].isMultiLine, isFalse);
      expect(blocks[1].content, equals('Some text after'));
    });

    test('parses tables as multi-line blocks', () {
      const text = '''
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |

Text after table''';

      final blocks = parseMarkdownBlocks(text);

      expect(blocks.length, equals(2));
      expect(blocks[0].isMultiLine, isTrue);
      expect(blocks[0].content, contains('| Header'));
      expect(blocks[1].content, equals('Text after table'));
    });

    test('parses blockquotes as blocks', () {
      const text = '''
> Quote line 1
> Quote line 2
> Quote line 3

Normal text''';

      final blocks = parseMarkdownBlocks(text);

      expect(blocks.length, equals(2));
      expect(blocks[0].isMultiLine, isTrue);
      expect(blocks[0].content, contains('> Quote'));
    });

    test('parses nested lists as multi-line blocks', () {
      const text = '''
- Item 1
  - Nested item
  - Another nested
- Item 2

Normal text''';

      final blocks = parseMarkdownBlocks(text);

      expect(blocks.length, greaterThanOrEqualTo(2));
      expect(blocks[0].isMultiLine, isTrue);
      expect(blocks[0].content, contains('- Item 1'));
      expect(blocks[0].content, contains('Nested'));
    });

    test('handles empty text', () {
      final blocks = parseMarkdownBlocks('');
      expect(blocks.length, equals(1));
      expect(blocks[0].content, equals(''));
    });

    test('handles text with only whitespace', () {
      const text = '   \n   \n   ';
      final blocks = parseMarkdownBlocks(text);

      // Each line becomes a block
      expect(blocks.length, equals(3));
    });
  });

  group('toggleCheckboxInText', () {
    test('toggles unchecked to checked', () {
      const text = '- [ ] Task 1\n- [ ] Task 2';
      final result = toggleCheckboxInText(text, 0, true);

      expect(result, isNotNull);
      expect(result, contains('- [x] Task 1'));
      expect(result, contains('- [ ] Task 2'));
    });

    test('toggles checked to unchecked', () {
      const text = '- [x] Task 1\n- [ ] Task 2';
      final result = toggleCheckboxInText(text, 0, false);

      expect(result, isNotNull);
      expect(result, contains('- [ ] Task 1'));
    });

    test('returns null for invalid index', () {
      const text = '- [ ] Task 1';
      final result = toggleCheckboxInText(text, 5, true);

      expect(result, isNull);
    });

    test('returns null when checkbox already in desired state', () {
      const text = '- [x] Task 1';
      final result = toggleCheckboxInText(text, 0, true);

      expect(result, isNull);
    });

    test('handles indented checkboxes', () {
      const text = '  - [ ] Indented task';
      final result = toggleCheckboxInText(text, 0, true);

      expect(result, isNotNull);
      expect(result, contains('[x]'));
    });

    test('handles uppercase X in checked boxes', () {
      const text = '- [X] Task with uppercase X';
      final result = toggleCheckboxInText(text, 0, false);

      expect(result, isNotNull);
      expect(result, contains('[ ]'));
    });
  });

  group('slugifyHeading', () {
    test('converts to lowercase', () {
      expect(slugifyHeading('Hello World'), equals('hello-world'));
    });

    test('replaces spaces with hyphens', () {
      expect(slugifyHeading('one two three'), equals('one-two-three'));
    });

    test('removes special characters', () {
      expect(slugifyHeading('Hello! @World# \$Test'), equals('hello-world-test'));
    });

    test('removes leading numbers with separators', () {
      expect(slugifyHeading('1. Introduction'), equals('introduction'));
      expect(slugifyHeading('2- Chapter'), equals('chapter'));
      expect(slugifyHeading('3_ Section'), equals('section'));
    });

    test('collapses multiple hyphens', () {
      expect(slugifyHeading('a---b'), equals('a-b'));
    });

    test('trims whitespace', () {
      expect(slugifyHeading('  Hello World  '), equals('hello-world'));
    });

    test('handles unicode characters', () {
      // Chinese characters should be kept
      final result = slugifyHeading('中文 标题');
      expect(result.contains('中文'), isTrue);
    });
  });
}
