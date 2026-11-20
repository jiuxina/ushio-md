import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/models/file_sort_option.dart';
import 'package:mdreader/screens/folder/components/folder_browser_header.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mdreader/widgets/glass_header_button.dart';

void main() {
  for (final searching in [true, false]) {
    testWidgets('folder header fits 320 at 200%, searching=$searching', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: 'Readability 搜索');
      addTearDown(controller.dispose);
      final colors = ColorScheme.fromSeed(seedColor: Colors.blue);
      final appStyle = AppStyleTheme.resolve(
        brightness: Brightness.light,
        colorScheme: colors,
        backgroundColor: Colors.white,
        textSecondary: Colors.grey,
        buttonStyleMode: AppButtonStyleMode.classic,
        cardOpacity: 0.4,
        customCardColor: const Color(0xFF101319),
      );
      final theme = ThemeData(colorScheme: colors, extensions: [appStyle]);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Column(
              children: [
                FolderBrowserHeader(
                  folderName: 'Synthetic folder',
                  fileCount: 3,
                  isSearching: searching,
                  onSearchToggle: () {},
                  searchController: controller,
                  onSearchChanged: (_) {},
                  sortOption: FileSortOption.nameAsc,
                  onSortChanged: (_) {},
                  onBack: () {},
                  showImages: true,
                  onImageToggle: () {},
                  onNewItem: () {},
                  onSelectionToggle: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (searching) {
        final input = tester.widget<TextField>(find.byType(TextField));
        final icon = input.decoration!.prefixIcon! as Icon;
        final palette = appStyle.resolveSurface(theme);
        for (final backdrop in [Colors.white, Colors.black]) {
          final background = Color.alphaBlend(palette.surface, backdrop);
          expect(
            ReadableSurfacePalette.contrastRatio(icon.color!, background),
            greaterThanOrEqualTo(3),
          );
        }
        expect(
          tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(66),
        );
      } else {
        expect(find.byType(GlassHeaderButton), findsNWidgets(6));
        for (final button in find.byType(GlassHeaderButton).evaluate()) {
          final box = button.renderObject! as RenderBox;
          expect(box.localToGlobal(Offset.zero).dx, greaterThanOrEqualTo(0));
          expect(
            box.localToGlobal(Offset(box.size.width, 0)).dx,
            lessThanOrEqualTo(320),
          );
        }
      }
      final backIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(GlassHeaderButton),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      expect(
        ReadableSurfacePalette.contrastRatio(
          backIcon.color!,
          const Color(0xFF101319),
        ),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
