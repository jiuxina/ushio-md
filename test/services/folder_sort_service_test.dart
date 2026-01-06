// ============================================================================
// FolderSortService 单元测试
// ============================================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mdreader/services/folder_sort_service.dart';

// Fake PathProvider
class FakePathProviderPlatform extends PathProviderPlatform {
  final String _tempPath;

  FakePathProviderPlatform(this._tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _tempPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('FolderSortService', () {
    late FolderSortService service;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('folder_sort_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      
      service = FolderSortService();
      service.reset();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('init 应该创建或读取配置文件', () async {
      await service.init();
      
      // 验证文件是否被创建 (saveOrder 会保存)
      // 如果没有数据，且 init 只是读，则不会创建文件。
      // 但我们检查内存状态应该为空
      expect(service.getSortOptionIndex('/some/path'), 0);
    });

    test('saveOrder 和 getOrder 应该持久化数据', () async {
      await service.init();
      
      final order = ['data.md', 'note.md'];
      await service.saveOrder('/test/path', order);
      
      expect(service.getOrder('/test/path'), order);
      
      // 验证文件持久化
      // 重置服务并重新读取
      service.reset();
      await service.init();
      expect(service.getOrder('/test/path'), order);
    });

    test('sortEntities 应该按照保存的顺序排序', () {
      final folderPath = '/test/path';
      final files = [
        File('$folderPath/note.md'),
        File('$folderPath/data.md'),
        File('$folderPath/about.md'),
      ];
      
      // 保存顺序: data.md, note.md (about.md 未在其中)
      // FolderSortService 内部逻辑:
      // 1. data.md (index 0)
      // 2. note.md (index 1)
      // 3. about.md (fallback: name sort)
      
      // 我们需要先设置内存状态 (mocking internal map would be easier but we use public API)
      // 这里调用 saveOrder 填充 _folderOrders
      // 注意: 这个测试是同步的，但 saveOrder 是异步的。
      // 为了测试 performace 里的 sortEntities，不需要 await saveOrder 写入磁盘，只要内存更新即可
      // 但 saveOrder 更新内存是同步的吗？
      // saveOrder 是 async, 但 map update 是在 await _save() 之前发生的
      // _folderOrders[folderPath] = filenames; await _save();
      // 所以如果不 await，直接调 sortEntities 可能会遇到 race condition (Dart is single threaded event loop, 
      // but execution suspends at await).
      // 只要 map update 在 first await 之前，就没事。
      // 不过为了安全，还是 mock 这里的行为，或者就在 test body 用 async。
    });

    test('sortEntities 逻辑验证', () async {
      final sep = Platform.pathSeparator;
      final folderPath = '${sep}test${sep}path';
      final fileData = File('$folderPath${sep}data.md');
      final fileNote = File('$folderPath${sep}note.md');
      final fileAbout = File('$folderPath${sep}about.md');
      
      // 设置自定义顺序
      await service.saveOrder(folderPath, ['data.md', 'note.md']);
      
      final sorted = service.sortEntities(folderPath, [fileNote, fileData, fileAbout]);
      
      expect(sorted.length, 3);
      expect(sorted[0].path, endsWith('data.md'));
      expect(sorted[1].path, endsWith('note.md'));
      expect(sorted[2].path, endsWith('about.md'));
    });
  });
}
