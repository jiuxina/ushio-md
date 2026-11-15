// ============================================================================
// 防抖和安全性测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mdreader/utils/debouncer.dart';

void main() {
  group('GlobalDebouncer.tryRun', () {
    test('单次操作正常执行', () async {
      int callCount = 0;

      final result = await GlobalDebouncer.tryRun('test1', () async {
        callCount++;
        return 42;
      });

      expect(result, equals(42));
      expect(callCount, equals(1));
    });

    test('并发操作只执行一次', () async {
      int callCount = 0;

      // 同时发起多个操作
      final futures = List.generate(
        10,
        (_) => GlobalDebouncer.tryRun('test2', () async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return callCount;
        }),
      );

      final results = await Future.wait(futures);

      // 只有一个操作应该执行
      expect(callCount, equals(1));
      // 其他调用应该返回 null
      final nonNullResults = results.where((r) => r != null).toList();
      expect(nonNullResults.length, equals(1));
    });

    test('顺序操作正常执行', () async {
      int callCount = 0;

      await GlobalDebouncer.tryRun('test3a', () async {
        callCount++;
        return null;
      });

      await GlobalDebouncer.tryRun('test3b', () async {
        callCount++;
        return null;
      });

      expect(callCount, equals(2));
    });

    test('不同 key 的操作独立执行', () async {
      int callCount = 0;

      await Future.wait([
        GlobalDebouncer.tryRun('key_a', () async {
          callCount++;
          return null;
        }),
        GlobalDebouncer.tryRun('key_b', () async {
          callCount++;
          return null;
        }),
      ]);

      expect(callCount, equals(2));
    });

    test('操作完成后可再次执行', () async {
      int callCount = 0;
      const key = 'test5';

      // 第一次操作
      await GlobalDebouncer.tryRun(key, () async {
        callCount++;
        return null;
      });

      // 等待操作完成
      await Future.delayed(const Duration(milliseconds: 10));

      // 第二次操作应该可以执行
      await GlobalDebouncer.tryRun(key, () async {
        callCount++;
        return null;
      });

      expect(callCount, equals(2));
    });
  });

  group('安全性边界测试', () {
    test('超长文件名截断', () {
      final longName = 'a' * 300 + '.md';
      final sanitized = FileService.sanitizeFileName(longName);

      expect(sanitized.length, lessThanOrEqualTo(255));
      expect(sanitized.endsWith('.md'), isTrue);
    });

    test('空文件名使用默认值', () {
      expect(FileService.sanitizeFileName(''), equals('untitled.md'));
      expect(FileService.sanitizeFileName('   '), equals('untitled.md'));
      expect(FileService.sanitizeFileName('.md'), equals('untitled.md'));
    });

    test('特殊字符被替换', () {
      expect(
        FileService.sanitizeFileName('test<file>.md'),
        equals('test_file_.md'),
      );
      expect(
        FileService.sanitizeFileName('file:name?.md'),
        equals('file_name_.md'),
      );
      expect(FileService.sanitizeFileName('test|"*.md'), equals('test___.md'));
    });

    test('路径遍历被移除', () {
      expect(
        FileService.sanitizeFileName('../../../etc/passwd'),
        equals('passwd'),
      );
      expect(
        FileService.sanitizeFileName('folder/../file.md'),
        equals('file.md'),
      );
    });

    test('Windows 保留名被处理', () {
      expect(FileService.sanitizeFileName('CON.md'), equals('_CON.md'));
      expect(FileService.sanitizeFileName('PRN'), equals('_PRN'));
      expect(FileService.sanitizeFileName('COM1.md'), equals('_COM1.md'));
    });
  });
}
