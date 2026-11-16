import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixturePaths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(Directory.current.path, 'build', 'batch-metadata-tests');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'moves and removals update descendant references without prefix matches',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final old = p.join(Directory.current.path, 'build', 'old');
      final moved = p.join(Directory.current.path, 'build', 'moved');
      final child = p.join(old, 'nested', 'document.md');
      final sibling = '${old}er${p.separator}keep.md';
      SharedPreferences.setMockInitialValues({
        'recent_files': [child, sibling],
        'pinned_files': [child],
        'recent_folders': [old, p.join(old, 'nested')],
        'pinned_folders': [old],
        'last_opened_file_path': child,
      });
      final provider = FileProvider();
      final settings = SettingsProvider();
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FixturePaths();
      addTearDown(() => PathProviderPlatform.instance = previousPaths);
      await settings.initialize();
      // The mutation applies to persisted lists even when existence validation
      // has not run (the source may already have moved when this is called).
      await provider.applyFilePathChanges({old: moved});
      await settings.applyFilePathChanges({old: moved});

      final prefs = await SharedPreferences.getInstance();
      final movedChild = p.join(moved, 'nested', 'document.md');
      expect(prefs.getStringList('recent_files'), [movedChild, sibling]);
      expect(prefs.getStringList('pinned_files'), [movedChild]);
      expect(prefs.getStringList('recent_folders'), [
        moved,
        p.join(moved, 'nested'),
      ]);
      expect(settings.lastOpenedFilePath, movedChild);
      expect(prefs.getString('last_opened_file_path'), movedChild);

      await provider.applyFilePathChanges({moved: null});
      await settings.applyFilePathChanges({moved: null});
      expect(prefs.getStringList('recent_files'), [sibling]);
      expect(prefs.getStringList('pinned_files'), isEmpty);
      expect(prefs.getStringList('recent_folders'), isEmpty);
      expect(settings.lastOpenedFilePath, isNull);
      expect(prefs.getString('last_opened_file_path'), isNull);
      provider.dispose();
      settings.dispose();
    },
  );
}
