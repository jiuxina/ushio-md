import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/screens/folder_browser_screen.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('selection supports invert, filtering and cancellation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = FileProvider();
    final settings = SettingsProvider();
    addTearDown(provider.dispose);
    addTearDown(settings.dispose);
    late Directory folder;
    await tester.runAsync(() async {
      final fixtures = await Directory(
        p.join(Directory.current.path, 'build', 'folder-selection-tests'),
      ).create(recursive: true);
      folder = await fixtures.createTemp('case-');
      await File(p.join(folder.path, 'alpha.md')).writeAsString('alpha');
      await File(p.join(folder.path, 'beta.md')).writeAsString('beta');
      await Directory(p.join(folder.path, 'nested')).create();
    });
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: settings),
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
        home: FolderBrowserScreen(
          folderPath: folder.path,
          showBackButton: false,
        ),
      ),
    ));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 10));
      if (find.text('alpha.md').evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const ValueKey('select-items')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-items')));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(3));
    await tester.tap(find.text('alpha.md'));
    await tester.pump();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).where((c) => c.value!),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('invert-selection')));
    await tester.pump();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).where((c) => c.value!),
      hasLength(2),
    );
    await tester.tap(find.byKey(const ValueKey('selection-search')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.byKey(const ValueKey('cancel-selection')));
    await tester.pump();
    expect(find.byType(Checkbox), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
