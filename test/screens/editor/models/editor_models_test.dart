// ============================================================================
// 编辑器模型测试
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ushio_md/screens/editor/models/editor_models.dart';

void main() {
  group('MarkdownBlock', () {
    test('creates with required parameters', () {
      const block = MarkdownBlock(
        startLine: 0,
        endLine: 5,
        content: '# Title\n\nParagraph',
        isMultiLine: true,
      );

      expect(block.startLine, equals(0));
      expect(block.endLine, equals(5));
      expect(block.content, equals('# Title\n\nParagraph'));
      expect(block.isMultiLine, isTrue);
    });

    test('lineCount is calculated correctly', () {
      const singleLine = MarkdownBlock(
        startLine: 0,
        endLine: 0,
        content: 'Single line',
        isMultiLine: false,
      );
      expect(singleLine.lineCount, equals(1));

      const multiLine = MarkdownBlock(
        startLine: 0,
        endLine: 4,
        content: 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5',
        isMultiLine: true,
      );
      expect(multiLine.lineCount, equals(5));
    });

    test('toString returns meaningful representation', () {
      const block = MarkdownBlock(
        startLine: 2,
        endLine: 5,
        content: 'content',
        isMultiLine: true,
      );

      expect(block.toString(), contains('MarkdownBlock'));
      expect(block.toString(), contains('start: 2'));
      expect(block.toString(), contains('end: 5'));
    });
  });

  group('EditHistoryEntry', () {
    test('creates with required parameters', () {
      const entry = EditHistoryEntry(
        text: 'Hello World',
        selection: TextSelection.collapsed(offset: 5),
      );

      expect(entry.text, equals('Hello World'));
      expect(entry.selection.baseOffset, equals(5));
    });

    test('toString returns meaningful representation', () {
      const entry = EditHistoryEntry(
        text: 'A' * 100,
        selection: TextSelection.collapsed(offset: 0),
      );

      expect(entry.toString(), contains('EditHistoryEntry'));
      expect(entry.toString(), contains('100 chars'));
    });
  });

  group('SearchMatch', () {
    test('creates with required parameters', () {
      const match = SearchMatch(
        position: 10,
        length: 5,
        preview: 'Hello World Test',
        occurrence: 0,
      );

      expect(match.position, equals(10));
      expect(match.length, equals(5));
      expect(match.preview, equals('Hello World Test'));
      expect(match.occurrence, equals(0));
    });

    test('toString returns meaningful representation', () {
      const match = SearchMatch(
        position: 42,
        length: 3,
        preview: 'preview',
        occurrence: 2,
      );

      expect(match.toString(), contains('SearchMatch'));
      expect(match.toString(), contains('pos: 42'));
      expect(match.toString(), contains('occ: 2'));
    });
  });
}
