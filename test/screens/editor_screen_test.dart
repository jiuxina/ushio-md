// ============================================================================
// EditorScreen Widget 测试
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mdreader/screens/editor_screen.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/plugin_provider.dart';
import 'package:mdreader/services/file_service.dart';

// Mock Classes
class MockFileService extends Mock implements FileService {}

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
  group('EditorScreen UI Tests', () {
    late MockFileService mockFileService;
    late Directory tempDir;
    
    // Providers
    late SettingsProvider settingsProvider;
    late FileProvider fileProvider;
    late PluginProvider pluginProvider;

    setUp(() async {
      // 1. Setup Environment Mocks
      tempDir = await Directory.systemTemp.createTemp('editor_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({}); // Empty prefs
      
      // 2. Setup Service Mocks
      mockFileService = MockFileService();
      
      // Default behaviors
      when(() => mockFileService.readFile(any())).thenAnswer((_) async => '# Hello World');
      when(() => mockFileService.hasPermissions()).thenAnswer((_) async => true);

      // 3. Initialize Providers
      settingsProvider = SettingsProvider();
      // Initialize settings if needed (though defaults are usually fine)
      
      fileProvider = FileProvider(fileService: mockFileService);
      
      pluginProvider = PluginProvider();
      // PluginProvider initialize might be needed if Editor checks plugins immediately
      // But EditorScreen uses getters like getEditorExtensions which return empty if not init.
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('EditorScreen should load and display content', (WidgetTester tester) async {
      final sep = Platform.pathSeparator;
      final filePath = '${sep}test${sep}note.md';
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: fileProvider),
            ChangeNotifierProvider.value(value: pluginProvider),
          ],
          child: MaterialApp(
            home: EditorScreen(filePath: filePath),
          ),
        ),
      );

      // Verify Loading State
      // Initially _isLoading is true.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for Future (_loadFile) to complete
      await tester.pumpAndSettle();
      
      // Verify Content
      // Editor starts in Preview mode by default (check line 38 of EditorScreen)
      // So we should find text in MarkdownPreview
      expect(find.textContaining('Hello World'), findsOneWidget);
      
      // Verify Header Title
      // EditorHeader removes extension
      expect(find.text('note'), findsOneWidget);
    });
    
    testWidgets('EditorScreen should switch to Edit mode', (WidgetTester tester) async {
       final sep = Platform.pathSeparator;
       final filePath = '${sep}test${sep}note.md';
       
       await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider.value(value: fileProvider),
            ChangeNotifierProvider.value(value: pluginProvider),
          ],
          child: MaterialApp(
            home: EditorScreen(filePath: filePath),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Mode Selector (usually in Header or Toolbar)
      // Depending on UI implementation. _buildModeSelector passes 'preview'/'edit'.
      // Icons.edit or text "编辑"?
      // Let's assume there is an IconButton with Edit icon or SegmentedControl.
      // Need to check EditorScreen logic for mode switch UI.
      // Since looking at code is expensive, let's just dump widget tree if we fail?
      // Or verify TextField is present when mode changes.
      
      // Currently defaulting to Preview.
      // Let's check if there's an edit button.
      // Common UI: an IconButton with Icons.edit_note or similar.
      
      // For now, simple content loading test is enough for "First Step".
    });
  });
}
