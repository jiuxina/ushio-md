import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/screens/folder_browser_screen.dart';
import 'package:mdreader/screens/main/tabs/my_files_tab.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TabPaths extends PathProviderPlatform {
  _TabPaths(this.documents);

  String? documents;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    if (documents == null) {
      throw PlatformException(code: 'storage_unavailable');
    }
    return documents;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;

  testWidgets(
    'offers retry after storage failure and opens the recovered workspace',
    (tester) async {
      final paths = _TabPaths(null);
      PathProviderPlatform.instance = paths;
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      final fileProvider = FileProvider();
      addTearDown(() {
        PathProviderPlatform.instance = originalPaths;
        settings.dispose();
        fileProvider.dispose();
      });
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: fileProvider),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: ThemeData(
              colorScheme: scheme,
              extensions: [
                AppStyleTheme.resolve(
                  brightness: Brightness.light,
                  colorScheme: scheme,
                  backgroundColor: scheme.surface,
                  textSecondary: scheme.onSurfaceVariant,
                  buttonStyleMode: AppButtonStyleMode.classic,
                  cardOpacity: 1,
                ),
              ],
            ),
            home: Scaffold(body: MyFilesTab(fileProvider: fileProvider)),
          ),
        ),
      );
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('重试').evaluate().isNotEmpty) break;
      }

      expect(find.text('重试'), findsOneWidget);
      expect(find.textContaining('无法打开文件目录'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FolderBrowserScreen), findsNothing);

      late String recoveredBase;
      await tester.runAsync(() async {
        final fixtures = await Directory(
          p.join(Directory.current.path, '.sisyphus', 'workspace-tests'),
        ).create(recursive: true);
        recoveredBase = (await fixtures.createTemp('tab-retry-')).path;
        paths.documents = recoveredBase;
      });
      await tester.tap(find.text('重试'));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(FolderBrowserScreen).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }

      expect(find.text('重试'), findsNothing);
      expect(find.byType(FolderBrowserScreen), findsOneWidget);
      expect(
        tester
            .widget<FolderBrowserScreen>(find.byType(FolderBrowserScreen))
            .folderPath,
        p.join(recoveredBase, 'Ushio-md'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
