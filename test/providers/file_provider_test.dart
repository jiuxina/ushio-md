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
      when(() => mockFileService.hasPermissions()).thenAnswer((_) async => true);
      
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
      
      // 手动注入（绕过 addToRecentFiles）或使用 addToRecentFiles 然后删除文件
      await provider.addToRecentFiles(path);
      await provider.addToRecentFiles(nonExistentPath); // 添加时未检查存在性？
      // FileProvider.addToRecentFiles 并不检查文件是否存在，只是添加路径。
      // 但是 getter 会过滤。
      
      // 此时 _recentFiles 包含两个路径
      // 但 recentFiles getter 应该只返回存在的那个
      expect(provider.recentFiles, contains(path));
      expect(provider.recentFiles, isNot(contains(nonExistentPath)));
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

    test('setDirectory 应调用 fileService 并更新 files', () async {
      final path = tempDir.path;
      final file = MarkdownFile(
        path: '$path/test.md',
        name: 'test.md',
        lastModified: DateTime.now(),
        size: 100,
      );
      
      when(() => mockFileService.listMarkdownFiles(path))
          .thenAnswer((_) async => [file]);
          
      await provider.setDirectory(path);
      
      expect(provider.isLoading, false);
      expect(provider.currentDirectory, path);
      expect(provider.files.length, 1);
      expect(provider.files.first, file);
      
      verify(() => mockFileService.listMarkdownFiles(path)).called(1);
    });
  });
}
