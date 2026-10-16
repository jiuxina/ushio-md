import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/models/markdown_file.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mdreader/utils/file_actions.dart';
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
  group('showCreateFileInFolderDialog', () {
    late Directory tempDir;
    late MockFileService fileService;
    late FileProvider fileProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('create_refresh_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});

      fileService = MockFileService();
      // 不落盘：真实文件 IO 要等 runAsync，会让断言抢在创建流程完成之前跑掉。
      when(() => fileService.createFile(any(), any())).thenAnswer((
        invocation,
      ) async {
        final directory = invocation.positionalArguments[0] as String;
        final name = invocation.positionalArguments[1] as String;
        return MarkdownFile(
          path: '$directory${Platform.pathSeparator}$name',
          name: name,
          content: '# $name\n\n',
          lastModified: DateTime.now(),
          size: 0,
        );
      });

      fileProvider = FileProvider(fileService: fileService);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Future<int> runCreateFlow(WidgetTester tester) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: fileProvider),
            ChangeNotifierProvider.value(value: SettingsProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (sheetContext) => TextButton(
                        onPressed: () {
                          // 镜像 folder_browser_screen 的真实调用：先收起菜单，
                          // 再把菜单自己的 context 交给创建流程。
                          Navigator.pop(sheetContext);
                          FileActions.showCreateFileInFolderDialog(
                            sheetContext,
                            tempDir.path,
                            fileProvider,
                            onRefresh: () => refreshCount++,
                          );
                        },
                        child: const Text('newMarkdown'),
                      ),
                    );
                  },
                  child: const Text('trigger'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('newMarkdown'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'note');
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      return refreshCount;
    }

    testWidgets(
      'refreshes the list even when it was started from a dismissed sheet',
      (tester) async {
        expect(await runCreateFlow(tester), 1);
      },
    );
  });
}
