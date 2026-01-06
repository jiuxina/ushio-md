// ============================================================================
// FileService 单元测试
// ============================================================================

import 'dart:io';
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
      expect(content, startsWith('# newfile.md'));
    });

    test('createFile 如果文件已存在应抛出异常', () async {
      await service.createFile(tempDir.path, 'dup');
      
      expect(
        () => service.createFile(tempDir.path, 'dup'),
        throwsException,
      );
    });

    test('renameFile 应重命名文件', () async {
      final oldFile = await service.createFile(tempDir.path, 'old');
      final newPath = await service.renameFile(oldFile.path, 'new');
      
      expect(await File(oldFile.path).exists(), false);
      expect(await File(newPath).exists(), true);
      expect(newPath.endsWith('new.md'), true);
    });

    test('deleteFile 应删除文件', () async {
      final file = await service.createFile(tempDir.path, 'delete_me');
      await service.deleteFile(file.path);
      
      expect(await File(file.path).exists(), false);
    });
  });
}
