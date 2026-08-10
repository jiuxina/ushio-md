// ============================================================================
// 文件服务安全性测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/file_service.dart';

void main() {
  group('FileService.sanitizeFileName', () {
    group('正常文件名', () {
      test('保留有效的文件名', () {
        expect(FileService.sanitizeFileName('test.md'), equals('test.md'));
        expect(FileService.sanitizeFileName('my-file.md'), equals('my-file.md'));
        expect(FileService.sanitizeFileName('文件名.md'), equals('文件名.md'));
        expect(FileService.sanitizeFileName('test_file.md'), equals('test_file.md'));
      });

      test('自动添加 .md 扩展名', () {
        final result = FileService.sanitizeFileName('test');
        expect(result, equals('test.md'));
      });

      test('处理空文件名', () {
        expect(FileService.sanitizeFileName(''), equals('untitled.md'));
        expect(FileService.sanitizeFileName('   '), equals('untitled.md'));
        expect(FileService.sanitizeFileName('.md'), equals('untitled.md'));
      });
    });

    group('Windows 非法字符', () {
      test('替换 < > : " | ? *', () {
        expect(
          FileService.sanitizeFileName('test<file>.md'),
          equals('test_file_.md'),
        );
        expect(
          FileService.sanitizeFileName('file:name?.md'),
          equals('file_name_.md'),
        );
        expect(
          FileService.sanitizeFileName('test|"*.md'),
          equals('test__.md'),
        );
      });

      test('处理所有非法字符组合', () {
        final result = FileService.sanitizeFileName('a<b>c:d"e|f?g*h.md');
        expect(result, equals('a_b_c_d_e_f_g_h.md'));
      });
    });

    group('控制字符', () {
      test('移除空字符', () {
        expect(
          FileService.sanitizeFileName('test\x00file.md'),
          equals('testfile.md'),
        );
      });

      test('移除换行符', () {
        expect(
          FileService.sanitizeFileName('test\nfile.md'),
          equals('testfile.md'),
        );
      });

      test('移除回车符', () {
        expect(
          FileService.sanitizeFileName('test\rfile.md'),
          equals('testfile.md'),
        );
      });

      test('移除制表符', () {
        expect(
          FileService.sanitizeFileName('test\tfile.md'),
          equals('testfile.md'),
        );
      });
    });

    group('Windows 保留名', () {
      test('CON 添加前缀', () {
        expect(FileService.sanitizeFileName('CON.md'), equals('_CON.md'));
        expect(FileService.sanitizeFileName('CON'), equals('_CON.md'));
      });

      test('PRN 添加前缀', () {
        expect(FileService.sanitizeFileName('PRN.md'), equals('_PRN.md'));
      });

      test('AUX 添加前缀', () {
        expect(FileService.sanitizeFileName('AUX.md'), equals('_AUX.md'));
      });

      test('NUL 添加前缀', () {
        expect(FileService.sanitizeFileName('NUL.md'), equals('_NUL.md'));
      });

      test('COM1-COM9 添加前缀', () {
        expect(FileService.sanitizeFileName('COM1.md'), equals('_COM1.md'));
        expect(FileService.sanitizeFileName('com9.md'), equals('_com9.md'));
      });

      test('LPT1-LPT9 添加前缀', () {
        expect(FileService.sanitizeFileName('LPT1.md'), equals('_LPT1.md'));
      });
    });

    group('路径处理', () {
      test('移除路径分隔符，只保留文件名', () {
        expect(
          FileService.sanitizeFileName('path/to/file.md'),
          equals('file.md'),
        );
        expect(
          FileService.sanitizeFileName('C:\\Users\\test.md'),
          equals('test.md'),
        );
        expect(
          FileService.sanitizeFileName('../secret.md'),
          equals('secret.md'),
        );
      });

      test('处理多层路径', () {
        expect(
          FileService.sanitizeFileName('a/b/c/d/file.md'),
          equals('file.md'),
        );
      });
    });

    group('长度限制', () {
      test('截断超长文件名', () {
        final longName = 'a' * 300 + '.md';
        final result = FileService.sanitizeFileName(longName);
        expect(result.length, lessThanOrEqualTo(255));
        expect(result.endsWith('.md'), isTrue);
      });

      test('保留扩展名', () {
        final longName = 'a' * 300 + '.md';
        final result = FileService.sanitizeFileName(longName);
        expect(result, endsWith('.md'));
      });
    });

    group('边界情况', () {
      test('处理首尾空格和点', () {
        expect(FileService.sanitizeFileName('  test.md  '), equals('test.md'));
        expect(FileService.sanitizeFileName('.test.md.'), equals('test.md'));
        expect(FileService.sanitizeFileName('...test...md...'), equals('test...md'));
      });

      test('处理多个点', () {
        expect(FileService.sanitizeFileName('test.file.name.md'), equals('test.file.name.md'));
      });

      test('自定义默认名', () {
        expect(
          FileService.sanitizeFileName('', defaultName: 'newfile'),
          equals('newfile.md'),
        );
        expect(
          FileService.sanitizeFileName('.md', defaultName: 'document'),
          equals('document.md'),
        );
      });
    });
  });

  group('FileService.formatFileSize', () {
    test('格式化字节', () {
      expect(FileService.formatFileSize(0), equals('0 B'));
      expect(FileService.formatFileSize(100), equals('100 B'));
      expect(FileService.formatFileSize(1023), equals('1023 B'));
    });

    test('格式化 KB', () {
      expect(FileService.formatFileSize(1024), equals('1.0 KB'));
      expect(FileService.formatFileSize(1536), equals('1.5 KB'));
      expect(FileService.formatFileSize(1024 * 1023), equals('1023.0 KB'));
    });

    test('格式化 MB', () {
      expect(FileService.formatFileSize(1024 * 1024), equals('1.0 MB'));
      expect(FileService.formatFileSize(1024 * 1024 * 10), equals('10.0 MB'));
    });
  });

  group('FileService.isFileTooLarge', () {
    test('小文件不超限', () {
      expect(FileService.isFileTooLarge(0), isFalse);
      expect(FileService.isFileTooLarge(1024), isFalse);
      expect(FileService.isFileTooLarge(1024 * 1024), isFalse); // 1 MB
      expect(FileService.isFileTooLarge(10 * 1024 * 1024 - 1), isFalse); // 10 MB - 1
    });

    test('大文件超限', () {
      expect(FileService.isFileTooLarge(10 * 1024 * 1024), isTrue); // 10 MB
      expect(FileService.isFileTooLarge(20 * 1024 * 1024), isTrue); // 20 MB
      expect(FileService.isFileTooLarge(100 * 1024 * 1024), isTrue); // 100 MB
    });
  });

  group('FileTooLargeException', () {
    test('创建异常并获取属性', () {
      const exception = FileTooLargeException(
        '文件过大',
        20 * 1024 * 1024,
        10 * 1024 * 1024,
      );

      expect(exception.message, equals('文件过大'));
      expect(exception.actualSize, equals(20 * 1024 * 1024));
      expect(exception.maxSize, equals(10 * 1024 * 1024));
    });

    test('toString 返回消息', () {
      const exception = FileTooLargeException(
        '文件过大 (20.0 MB)，最大支持 10.0 MB',
        20 * 1024 * 1024,
        10 * 1024 * 1024,
      );

      expect(exception.toString(), contains('文件过大'));
    });
  });
}
