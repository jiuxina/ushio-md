// ============================================================================
// FileService 单元测试
// ============================================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/file_service.dart';

void main() {
  group('FileService', () {
    late FileService service;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mdreader_service_test');
      service = FileService();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('listMarkdownFiles 应递归列出所有 md 文件并忽略其他文件', () async {
      // 创建测试文件结构
      // root/
      //   note1.md
      //   image.png
      //   sub/
      //     note2.markdown
      //     data.txt

      final subDir = Directory('${tempDir.path}/sub');
      await subDir.create();

      await File('${tempDir.path}/note1.md').create();
      await File('${tempDir.path}/image.png').create();
      await File('${subDir.path}/note2.markdown').create();
      await File('${subDir.path}/data.txt').create();

      final files = await service.listMarkdownFiles(tempDir.path);

      expect(files.length, 2);

      // 验证包含 note1.md 和 note2.markdown
      final names = files.map((f) => f.name).toList();
      // FileService implementation uses split(separator).last
      // On Windows separator is \, on Linux /.
      // But verify logical names.
      expect(names, containsAll(['note1.md', 'note2.markdown']));
    });

    test('createFile 应创建文件并写入初始内容', () async {
      final file = await service.createFile(tempDir.path, 'newfile');

      expect(file.name, 'newfile.md');
      expect(await File(file.path).exists(), true);

      final content = await File(file.path).readAsString();
      expect(content, startsWith('# newfile'));
    });

    test('looksLikeTextBytes 识别文本与二进制，截断多字节字符不误判', () {
      expect(FileService.looksLikeTextBytes(utf8.encode('hello 汐')), true);
      expect(FileService.looksLikeTextBytes([0x00, 0x01, 0x02]), false);
      expect(
        FileService.looksLikeTextBytes([0xE4, 0xB8]),
        true,
      );
    });

    test('normalizeLineEndings 保留 CRLF / 归一化 LF', () {
      expect(
        FileService.normalizeLineEndings('a\nb\n', lineEnding: '\r\n'),
        'a\r\nb\r\n',
      );
      expect(
        FileService.normalizeLineEndings('a\r\nb\r\n'),
        'a\nb\n',
      );
    });

    test('readFile 对非法 UTF-8 抛出 FileEncodingException', () async {
      final file = File('${tempDir.path}/invalid_utf8.md');
      await file.writeAsBytes([0x68, 0x69, 0xC3, 0x28]);

      expect(
        () => service.readFile(file.path),
        throwsA(isA<FileEncodingException>()),
      );
    });

    test('readFile 对二进制内容抛出 FileEncodingException', () async {
      final file = File('${tempDir.path}/binary.md');
      await file.writeAsBytes([0x00, 0x01, 0x02, 0x03]);

      expect(
        () => service.readFile(file.path),
        throwsA(isA<FileEncodingException>()),
      );
    });

    test('createFile 如果文件已存在应抛出异常', () async {
      await service.createFile(tempDir.path, 'dup');

      expect(() => service.createFile(tempDir.path, 'dup'), throwsException);
    });

    test('renameFile 应重命名文件', () async {
      final oldFile = await service.createFile(tempDir.path, 'old');
      final newPath = await service.renameFile(oldFile.path, 'new');

      expect(await File(oldFile.path).exists(), false);
      expect(await File(newPath).exists(), true);
      expect(newPath.endsWith('new.md'), true);
    });

    test('renameFile 应保留显式 .markdown 扩展名', () async {
      final oldFile = await service.createFile(tempDir.path, 'old');
      final newPath = await service.renameFile(
        oldFile.path,
        'renamed.markdown',
      );

      expect(newPath.endsWith('renamed.markdown'), true);
      expect(await File(newPath).exists(), true);
    });

    test('ensureMarkdownExtension 未指定后缀时默认补 .md', () {
      expect(FileService.ensureMarkdownExtension('note'), 'note.md');
      expect(FileService.ensureMarkdownExtension('note.md'), 'note.md');
      expect(
        FileService.ensureMarkdownExtension('note.markdown'),
        'note.markdown',
      );
      expect(FileService.ensureMarkdownExtension('note.MD'), 'note.MD');
      expect(FileService.ensureMarkdownExtension('note.txt'), 'note.txt');
    });

    test('deleteFile 应删除文件', () async {
      final file = await service.createFile(tempDir.path, 'delete_me');
      await service.deleteFile(file.path);

      expect(await File(file.path).exists(), false);
    });

    test('preloadFile 应缓存内容并命中内存缓存', () async {
      final file = await service.createFile(tempDir.path, 'cached');
      await File(file.path).writeAsString('hello cache');

      final first = await service.preloadFile(file.path);
      final second = await service.readFile(file.path);

      expect(first, 'hello cache');
      expect(second, 'hello cache');
      expect(service.isFileCached(file.path), true);
    });

    test('文件修改后应使旧缓存失效', () async {
      final file = await service.createFile(tempDir.path, 'stale');
      await File(file.path).writeAsString('version 1');
      await service.preloadFile(file.path);

      await File(file.path).writeAsString('version 2 with different length');

      final refreshed = await service.readFile(file.path);
      expect(refreshed, 'version 2 with different length');
    });
  });
}
