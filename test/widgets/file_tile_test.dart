import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/plugin_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/screens/folder/components/file_tile.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFileService extends Mock implements FileService {}

class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;

  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  group('FileTile', () {
    late Directory tempDir;
    late File file;
    late MockFileService mockFileService;
    late FileProvider fileProvider;
    late SettingsProvider settingsProvider;
    late PluginProvider pluginProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_tile_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});

      file = File('${tempDir.path}/note.md');
      await file.writeAsString('# History Note');

      mockFileService = MockFileService();
      when(() => mockFileService.hasPermissions()).thenAnswer((_) async => true);
      when(() => mockFileService.isFileCached(any())).thenReturn(false);
      when(() => mockFileService.preloadFile(any()))
          .thenAnswer((_) async => '# History Note');
      when(() => mockFileService.readFile(any()))
          .thenAnswer((_) async => '# History Note');

      fileProvider = FileProvider(fileService: mockFileService);
      settingsProvider = SettingsProvider();
      pluginProvider = PluginProvider();
      await fileProvider.addToRecentFiles(file.path);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('opens markdown files from history without getting stuck',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: fileProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: pluginProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FileTile(
                entity: file,
                source: FileSource.history,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FileTile));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('note'), findsOneWidget);
      expect(fileProvider.recentFiles.first, file.path);
    });
  });
}
