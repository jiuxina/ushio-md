// ============================================================================
// 防抖和安全性测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debouncer', () {
    test('单次操作正常执行', () async {
      int callCount = 0;
      
      final result = await _TestDebouncer.run('test1', () async {
        callCount++;
        return 42;
      });
      
      expect(result, equals(42));
      expect(callCount, equals(1));
    });

    test('并发操作只执行一次', () async {
      int callCount = 0;
      
      // 同时发起多个操作
      final futures = List.generate(10, (_) => 
        _TestDebouncer.run('test2', () async {
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
      
      await _TestDebouncer.run('test3a', () async {
        callCount++;
        return null;
      });
      
      await _TestDebouncer.run('test3b', () async {
        callCount++;
        return null;
      });
      
      expect(callCount, equals(2));
    });

    test('不同 key 的操作独立执行', () async {
      int callCount = 0;
      
      await Future.wait([
        _TestDebouncer.run('key_a', () async {
          callCount++;
          return null;
        }),
        _TestDebouncer.run('key_b', () async {
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
      await _TestDebouncer.run(key, () async {
        callCount++;
        return null;
      });
      
      // 等待操作完成
      await Future.delayed(const Duration(milliseconds: 10));
      
      // 第二次操作应该可以执行
      await _TestDebouncer.run(key, () async {
        callCount++;
        return null;
      });
      
      expect(callCount, equals(2));
    });
  });

  group('安全性边界测试', () {
    test('超长文件名截断', () {
      final longName = 'a' * 300 + '.md';
      final sanitized = _sanitizeFileName(longName);
      
      expect(sanitized.length, lessThanOrEqualTo(255));
      expect(sanitized.endsWith('.md'), isTrue);
    });

    test('空文件名使用默认值', () {
      expect(_sanitizeFileName(''), equals('untitled.md'));
      expect(_sanitizeFileName('   '), equals('untitled.md'));
      expect(_sanitizeFileName('.md'), equals('untitled.md'));
    });

    test('特殊字符被替换', () {
      expect(_sanitizeFileName('test<file>.md'), equals('test_file_.md'));
      expect(_sanitizeFileName('file:name?.md'), equals('file_name_.md'));
      expect(_sanitizeFileName('test|"*.md'), equals('test__.md'));
    });

    test('路径遍历被移除', () {
      expect(_sanitizeFileName('../../../etc/passwd'), equals('passwd.md'));
      expect(_sanitizeFileName('folder/../file.md'), equals('file.md'));
    });

    test('Windows 保留名被处理', () {
      expect(_sanitizeFileName('CON.md'), equals('_CON.md'));
      expect(_sanitizeFileName('PRN'), equals('_PRN.md'));
      expect(_sanitizeFileName('COM1.md'), equals('_COM1.md'));
    });
  });
}

/// 测试用防抖器
class _TestDebouncer {
  static final Map<String, bool> _operations = {};
  
  static bool startOperation(String key) {
    if (_operations[key] == true) return false;
    _operations[key] = true;
    return true;
  }
  
  static void endOperation(String key) {
    _operations[key] = false;
  }
  
  static Future<T?> run<T>(String key, Future<T> Function() operation) async {
    if (!startOperation(key)) return null;
    try {
      return await operation();
    } finally {
      endOperation(key);
    }
  }
}

/// 测试用文件名清理函数
String _sanitizeFileName(String name, {String defaultName = 'untitled'}) {
  var sanitized = name.trim();
  
  sanitized = sanitized.replaceAll('\\', '/').split('/').last.trim();
  sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*]'), '_');
  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1f]'), '');
  
  const reservedNames = [
    'CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  ];
  final baseName = sanitized.toUpperCase().split('.').first;
  if (reservedNames.contains(baseName)) {
    sanitized = '_$sanitized';
  }
  
  sanitized = sanitized.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  
  if (sanitized.length > 255) {
    final lastDot = sanitized.lastIndexOf('.');
    if (lastDot > 0 && lastDot > sanitized.length - 10) {
      final ext = sanitized.substring(lastDot);
      sanitized = sanitized.substring(0, 255 - ext.length) + ext;
    } else {
      sanitized = sanitized.substring(0, 255);
    }
  }
  
  if (sanitized.isEmpty || sanitized == '.md') {
    sanitized = '$defaultName.md';
  }
  
  return sanitized;
}
