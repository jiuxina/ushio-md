// ============================================================================
// FileProvider 单元测试
// ============================================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mdreader/models/markdown_file.dart';

// Mock FileService
class MockFileService extends Mock implements FileService {}

void main() {
  group('FileProvider', () {
    late FileProvider provider;
    late MockFileService mockFileService;
    late Directory tempDir;

    setUp(() async {
      // 准备临时目录和文件，因为 FileProvider 会检查文件是否存在
      tempDir = await Directory.systemTemp.createTemp('mdreader_test');

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Mock FileService
      mockFileService = MockFileService();
      when(
        () => mockFileService.hasPermissions(),
      ).thenAnswer((_) async => true);

      provider = FileProvider(fileService: mockFileService);
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    Future<String> createTempFile(String name) async {
      final file = File('${tempDir.path}/$name');
      await file.create();
      return file.path;
    }

    test('初始化状态应为空', () async {
      await provider.initialize();
      expect(provider.recentFiles, isEmpty);
      expect(provider.pinnedFiles, isEmpty);
    });

    test('addToRecentFiles 应添加文件并持久化', () async {
      final path = await createTempFile('test.md');

      await provider.addToRecentFiles(path);

      expect(provider.recentFiles.length, 1);
      expect(provider.recentFiles.first, path);

      // 验证 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_files'), [path]);
    });

    test('getters 应过滤不存在的文件', () async {
      final path = await createTempFile('exists.md');
      final nonExistentPath = '${tempDir.path}/non_existent.md';

      await provider.addToRecentFiles(path);
      await provider.addToRecentFiles(nonExistentPath);

      expect(provider.recentFiles, [path]);
    });

    test('再次访问现有文件时立即移到首位且不重复', () async {
      final first = await createTempFile('first.md');
      final second = await createTempFile('second.md');
      await provider.addToRecentFiles(first);
      await provider.addToRecentFiles(second);

      await provider.addToRecentFiles(first);

      expect(provider.recentFiles, [first, second]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_files'), [first, second]);
    });

    test('重新添加已经移走的文件时移除失效缓存', () async {
      final path = await createTempFile('moved.md');
      await provider.addToRecentFiles(path);
      await File(path).rename('${tempDir.path}/renamed.md');

      await provider.addToRecentFiles(path);

      expect(provider.recentFiles, isEmpty);
    });

    test('无效历史路径不会污染有效缓存或破坏数量上限', () async {
      final path = await createTempFile('exists.md');
      await provider.addToRecentFiles(path);
      for (var i = 0; i < 25; i++) {
        await provider.addToRecentFiles('${tempDir.path}/missing-$i.md');
      }
      await provider.addToRecentFiles(path);

      expect(provider.recentFiles, [path]);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('recent_files')!.length,
        lessThanOrEqualTo(20),
      );
    });

    test('togglePinFile 应切换置顶状态', () async {
      final path = await createTempFile('pinned.md');

      // Pin
      await provider.togglePinFile(path);
      expect(provider.pinnedFiles, contains(path));
      expect(provider.isFilePinned(path), true);

      // Unpin
      await provider.togglePinFile(path);
      expect(provider.pinnedFiles, isNot(contains(path)));
      expect(provider.isFilePinned(path), false);
    });

    test('togglePinFile 一次不应写入重复条目', () async {
      final path = await createTempFile('once.md');

      // 真实顺序：应用启动先 initialize()（内部会跑路径校验），之后用户才点置顶
      await provider.initialize();
      await provider.togglePinFile(path);

      expect(provider.pinnedFiles, [path]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('pinned_files'), [path]);

      // 再点一次取消，应该彻底消失而不是残留一份
      await provider.togglePinFile(path);
      expect(provider.pinnedFiles, isEmpty);
    });

    test('togglePinFolder 一次不应写入重复条目', () async {
      final dir = Directory('${tempDir.path}/pinned-dir')..createSync();

      await provider.initialize();
      await provider.togglePinFolder(dir.path);

      expect(provider.pinnedFolders, [dir.path]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('pinned_folders'), [dir.path]);

      await provider.togglePinFolder(dir.path);
      expect(provider.pinnedFolders, isEmpty);
    });

    test('历史遗留的重复置顶条目应在加载时去重', () async {
      final path = await createTempFile('legacy.md');
      SharedPreferences.setMockInitialValues({
        'pinned_files': [path, path],
      });

      final reloaded = FileProvider(fileService: mockFileService);
      await reloaded.initialize();

      expect(reloaded.pinnedFiles, [path]);
    });

    test('setDirectory 应调用 fileService 并更新 files', () async {
      final path = tempDir.path;
      final file = MarkdownFile(
        path: '$path/test.md',
        name: 'test.md',
        lastModified: DateTime.now(),
        size: 100,
      );

      when(
        () => mockFileService.listMarkdownFiles(path),
      ).thenAnswer((_) async => [file]);

      await provider.setDirectory(path);

      expect(provider.isLoading, false);
      expect(provider.currentDirectory, path);
      expect(provider.files.length, 1);
      expect(provider.files.first, file);

      verify(() => mockFileService.listMarkdownFiles(path)).called(1);
    });
  });
}
