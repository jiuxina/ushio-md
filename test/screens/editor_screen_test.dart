// ============================================================================
// EditorScreen Widget 测试
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mdreader/screens/editor_screen.dart';
import 'package:mdreader/screens/editor/components/editor_header.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mdreader/widgets/milkdown_webview_editor.dart';

// Mock Classes
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
  final String _tempPath;
  FakePathProviderPlatform(this._tempPath);
  @override
  Future<String?> getApplicationDocumentsPath() async => _tempPath;
  @override
  Future<String?> getApplicationSupportPath() async => _tempPath;
  @override
  Future<String?> getTemporaryPath() async => _tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;
  final originalWebViews = InAppWebViewPlatform.instance;

  group('EditorScreen UI Tests', () {
    late MockFileService mockFileService;
    late Directory tempDir;

    // Providers
    late SettingsProvider settingsProvider;
    late FileProvider fileProvider;

    setUp(() async {
      // 1. Setup Environment Mocks
      tempDir = await Directory.systemTemp.createTemp('editor_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({}); // Empty prefs
      InAppWebViewPlatform.instance = _TestWebViewPlatform();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            (call) async => call.method == 'isMaximized' ? false : null,
          );

      // 2. Setup Service Mocks
      mockFileService = MockFileService();

      // Default behaviors
      when(
        () => mockFileService.readFile(any()),
      ).thenAnswer((_) async => '# Hello World');
      when(
        () => mockFileService.hasPermissions(),
      ).thenAnswer((_) async => true);

      // 3. Initialize Providers
      settingsProvider = SettingsProvider();
      fileProvider = FileProvider(fileService: mockFileService);
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

    Widget editorApp(String filePath) {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: fileProvider),
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
          home: EditorScreen(filePath: filePath),
        ),
      );
    }

    testWidgets('EditorScreen should load and display content', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(warmUpMilkdownWebAssets);
      final sep = Platform.pathSeparator;
      final filePath = '${sep}test${sep}note.md';

      await tester.pumpWidget(editorApp(filePath));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Content
      // Editor now uses WebView for markdown rendering; text content lives inside
      // the WebView and is not part of the Flutter widget tree, so we verify the
      // header (file name) instead of the rendered markdown text.
      expect(find.byKey(const ValueKey('test-inappwebview')), findsOneWidget);
      verify(() => mockFileService.readFile(filePath)).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('EditorScreen should switch to Edit mode', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(warmUpMilkdownWebAssets);
      final sep = Platform.pathSeparator;
      final filePath = '${sep}test${sep}note.md';

      await tester.pumpWidget(editorApp(filePath));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final editor = tester.widget<TextField>(find.byType(TextField));
      expect(editor.controller!.text, '# Hello World');
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('mode switch stays in the header with floating buttons hidden', (
      tester,
    ) async {
      await settingsProvider.setFloatingButtonsMode('never');
      await tester.runAsync(warmUpMilkdownWebAssets);
      await tester.pumpWidget(editorApp('${tempDir.path}/header.md'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final toggle = find.descendant(
        of: find.byType(EditorHeader),
        matching: find.byIcon(Icons.edit),
      );
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(EditorHeader),
          matching: find.byIcon(Icons.visibility),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('background saves immediately only when auto save is enabled', (
      tester,
    ) async {
      await settingsProvider.setAutoSave(true);
      when(() => mockFileService.saveFile(any(), any()))
          .thenAnswer((_) async {});
      await tester.runAsync(warmUpMilkdownWebAssets);
      final filePath = '${tempDir.path}/background.md';
      await tester.pumpWidget(editorApp(filePath));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '最后输入的内容');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();
      verify(
        () => mockFileService.saveFile(filePath, '最后输入的内容'),
      ).called(1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('background leaves manual edits unsaved when auto save is off', (
      tester,
    ) async {
      await tester.runAsync(warmUpMilkdownWebAssets);
      await tester.pumpWidget(editorApp('${tempDir.path}/manual.md'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '手动保存');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      verifyNever(() => mockFileService.saveFile(any(), any()));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('edits made during a save remain dirty after that save', (
      tester,
    ) async {
      final pendingSave = Completer<void>();
      when(() => mockFileService.saveFile(any(), any()))
          .thenAnswer((_) => pendingSave.future);
      await tester.runAsync(warmUpMilkdownWebAssets);
      final filePath = '${tempDir.path}/concurrent.md';
      await tester.pumpWidget(editorApp(filePath));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'first snapshot');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      verify(
        () => mockFileService.saveFile(filePath, 'first snapshot'),
      ).called(1);
      await tester.enterText(find.byType(TextField), 'second snapshot');
      pendingSave.complete();
      await tester.pump();
      await tester.pump();
      expect(tester.widget<EditorHeader>(find.byType(EditorHeader)).isModified,
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
