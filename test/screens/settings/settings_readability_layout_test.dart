import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/screens/settings/about_screen.dart';
import 'package:mdreader/screens/settings/appearance/appearance_utils.dart';
import 'package:mdreader/screens/settings/appearance/background_settings_screen.dart';
import 'package:mdreader/screens/settings/appearance/font_settings_screen.dart';
import 'package:mdreader/screens/settings/cloud_sync_screen.dart';
import 'package:mdreader/screens/settings/editor_settings_screen.dart';
import 'package:mdreader/screens/settings/storage_settings_screen.dart';
import 'package:provider/provider.dart';

import 'appearance/appearance_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pages = <String, Widget>{
    'font settings': const FontSettingsScreen(),
    'surface settings': const BackgroundSettingsScreen(),
    'editor settings': const EditorSettingsScreen(),
    'storage settings': const StorageSettingsScreen(),
    'cloud settings': const CloudSyncScreen(),
    'about settings': const AboutScreen(),
  };

  for (final page in pages.entries) {
    testWidgets('${page.key} fits 320px with 200% text', (tester) async {
      final settings = await createAppearanceSettings();
      final files = FileProvider();
      await pumpAppearancePage(
        tester,
        settings,
        ChangeNotifierProvider<FileProvider>.value(
          value: files,
          child: page.value,
        ),
        logicalSize: const Size(320, 4000),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      files.dispose();
    });
  }

  testWidgets('color picker remains usable with keyboard and 200% text', (
    tester,
  ) async {
    final settings = await createAppearanceSettings();
    Color? selected;
    await pumpAppearancePage(
      tester,
      settings,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppearanceUtils.showColorPicker(
              context: context,
              initialColor: Colors.blue,
              title: 'Synthetic custom color',
              onColorSelected: (color) => selected = color,
            ),
            child: const Text('Open picker'),
          ),
        ),
      ),
      logicalSize: const Size(320, 800),
      textScale: 2,
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '#123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('确认'));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(selected, const Color(0xFF123456));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });
}
