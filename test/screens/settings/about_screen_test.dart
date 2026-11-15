import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/screens/settings/about_screen.dart';
import 'package:mdreader/screens/settings/open_source_licenses_screen.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpAboutScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider();
    addTearDown(settings.dispose);
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
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
          home: const AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('update button checks the configured release endpoint', (
    tester,
  ) async {
    await pumpAboutScreen(tester);
    expect(find.text('关于'), findsOneWidget);
    final updateTile = find.ancestor(
      of: find.text('检查更新'),
      matching: find.byType(ListTile),
    );
    final button = find.descendant(
      of: updateTile,
      matching: find.byType(TextButton),
    );
    expect(button, findsOneWidget);
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response('{"tag_name":"v0.0.0","assets":[]}', 200);
    });

    await http.runWithClient(() async {
      await tester.tap(button);
      await tester.pumpAndSettle();
    }, () => client);

    expect(requests, [
      Uri.parse(
        'https://api.github.com/repos/jiuxina/ushio-md/releases/latest',
      ),
    ]);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('open source license tile navigates to the license screen', (
    tester,
  ) async {
    await pumpAboutScreen(tester);
    final licenseTile = find.text('开放源代码许可');
    expect(licenseTile, findsOneWidget);

    await tester.tap(licenseTile);
    await tester.pumpAndSettle();

    expect(find.byType(OpenSourceLicensesScreen), findsOneWidget);
  });
}
