import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/screens/editor_screen.dart';
import 'package:mdreader/screens/folder/components/file_tile.dart';
import 'package:mdreader/utils/file_actions.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mdreader/widgets/milkdown_webview_editor.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFileService extends Mock implements FileService {}

class _TestWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewController createPlatformInAppWebViewControllerStatic() =>
      _TestWebViewController(
        const PlatformInAppWebViewControllerCreationParams(id: -1),
      );

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _TestWebViewWidget(params);
}

class _TestWebViewWidget extends PlatformInAppWebViewWidget {
  _TestWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('test-inappwebview'));

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnsupportedError(
        'Native controllers are outside this widget test.',
      );

  @override
  void dispose() {}
}

class _TestWebViewController extends PlatformInAppWebViewController {
  _TestWebViewController(super.params) : super.implementation();

  @override
  Future<void> setWebContentsDebuggingEnabled(bool debuggingEnabled) async {}
}

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
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;
  final originalWebViews = InAppWebViewPlatform.instance;

  group('FileTile', () {
    late Directory tempDir;
    late File file;
    late MockFileService mockFileService;
    late FileProvider fileProvider;
    late SettingsProvider settingsProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_tile_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});
      InAppWebViewPlatform.instance = _TestWebViewPlatform();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            (call) async => call.method == 'isMaximized' ? false : null,
          );

      file = File('${tempDir.path}/note.md');
      await file.writeAsString('# History Note');

      mockFileService = MockFileService();
      when(
        () => mockFileService.hasPermissions(),
      ).thenAnswer((_) async => true);
      when(() => mockFileService.isFileCached(any())).thenReturn(false);
      when(
        () => mockFileService.preloadFile(any()),
      ).thenAnswer((_) async => '# History Note');
      when(
        () => mockFileService.readFile(any()),
      ).thenAnswer((_) async => '# History Note');

      fileProvider = FileProvider(fileService: mockFileService);
      settingsProvider = SettingsProvider();
      await fileProvider.addToRecentFiles(file.path);
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPaths;
      if (originalWebViews != null) {
        InAppWebViewPlatform.instance = originalWebViews;
      }
      settingsProvider.dispose();
      fileProvider.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            null,
          );
    });

    testWidgets('opens markdown files from history without getting stuck', (
      tester,
    ) async {
      await tester.runAsync(warmUpMilkdownWebAssets);
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: fileProvider),
            ChangeNotifierProvider.value(value: settingsProvider),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            home: Scaffold(
              body: FileTile(entity: file, source: FileSource.history),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FileTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('test-inappwebview')), findsOneWidget);
      expect(fileProvider.recentFiles.first, file.path);
      verify(() => mockFileService.preloadFile(file.path)).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
