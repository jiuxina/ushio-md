// ============================================================================
// Markdown 增量合并回归测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/utils/markdown_incremental_merge.dart';

void main() {
  group('incrementalMerge 空行与特殊符号', () {
    test('语义等价内容应保留原格式且不膨胀空行', () {
      const original = '- 第一项\n\n- 第二项\n\n段落 – 内容';
      const newContent = '* 第一项\n\n* 第二项\n\n段落 – 内容';

      final result = incrementalMerge(
        original: original,
        newContent: newContent,
      );

      expect(result.content, original);
    });

    test('段落内容变化时保留特殊符号与单个空行', () {
      const original = '第一段 – 内容\n\n第二段';
      const newContent = '第一段 – 内容已改\n\n第二段';

      final result = incrementalMerge(
        original: original,
        newContent: newContent,
      );

      expect(result.content, '第一段 – 内容已改\n\n第二段');
      expect(result.content, contains('–'));
    });

    test('多个连续空行应精确保留', () {
      const original = '- A\n\n\n- B';
      const newContent = '* A\n\n\n* B';

      final result = incrementalMerge(
        original: original,
        newContent: newContent,
      );

      expect(result.content, original);
      expect(result.content, '- A\n\n\n- B');
    });

    test('结尾空行应精确保留', () {
      const original = '- A\n\n';
      const newContent = '* A\n\n';

      final result = incrementalMerge(
        original: original,
        newContent: newContent,
      );

      expect(result.content, original);
    });

    test('Milkdown 添加尾随空格时保留原文空行结构', () {
      const original = '标题\n\n内容';
      const newContent = '标题 \n\n内容';

      final result = incrementalMerge(
        original: original,
        newContent: newContent,
      );

      expect(result.content, original);
    });
  });
}
