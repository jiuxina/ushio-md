import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/widgets/liquid_glass_capsule_tab_bar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => 'C:/fake/documents';

  @override
  Future<String?> getApplicationSupportPath() async => 'C:/fake/support';

  @override
  Future<String?> getTemporaryPath() async => 'C:/fake/tmp';
}

const _destinations = [
  LiquidGlassCapsuleDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  LiquidGlassCapsuleDestination(
    icon: Icons.folder_special_outlined,
    selectedIcon: Icons.folder_special_rounded,
    label: 'My Files',
  ),
  LiquidGlassCapsuleDestination(
    icon: Icons.history_outlined,
    selectedIcon: Icons.history_rounded,
    label: 'History',
  ),
  LiquidGlassCapsuleDestination(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    label: 'Settings',
  ),
];

class _TabBarHarness extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onSelected;

  const _TabBarHarness({required this.initialIndex, this.onSelected});

  @override
  State<_TabBarHarness> createState() => _TabBarHarnessState();
}

class _TabBarHarnessState extends State<_TabBarHarness> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCapsuleTabBar(
      selectedIndex: _index,
      onDestinationSelected: (index) {
        widget.onSelected?.call(index);
        setState(() => _index = index);
      },
      destinations: _destinations,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> createSettings() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    final provider = SettingsProvider();
    await provider.initialize();
    return provider;
  }

  Future<void> pumpBar(
    WidgetTester tester, {
    required int selectedIndex,
    required ValueChanged<int> onDestinationSelected,
  }) async {
    final settings = await createSettings();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: _TabBarHarness(
                initialIndex: selectedIndex,
                onSelected: onDestinationSelected,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('渲染 4 个仅图标目的地', (tester) async {
    await pumpBar(
      tester,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
    );

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.folder_special_outlined), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Home',
      ),
      findsOneWidget,
    );
  });

  testWidgets('点击目的地会返回对应索引', (tester) async {
    int? tappedIndex;
    await pumpBar(
      tester,
      selectedIndex: 0,
      onDestinationSelected: (index) => tappedIndex = index,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();

    expect(tappedIndex, 3);
  });

  testWidgets('滑块中心对准选中图标并平滑过渡', (tester) async {
    await pumpBar(
      tester,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
    );

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsOneWidget);

    final pillFinder = find.byKey(const ValueKey('capsule_selection_pill'));
    final initialPillCenter = tester.getCenter(pillFinder);
    final homeIconCenter = tester.getCenter(find.byIcon(Icons.home_rounded));
    expect(initialPillCenter.dx, closeTo(homeIconCenter.dx, 0.5));
    expect(initialPillCenter.dy, closeTo(homeIconCenter.dy, 0.5));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    final settingsIconCenter = tester.getCenter(
      find.byIcon(Icons.settings_rounded),
    );

    final slideCenters = <double>[];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(pillFinder, findsOneWidget);
      slideCenters.add(tester.getCenter(pillFinder).dx);
    }
    for (var i = 0; i < slideCenters.length; i++) {
      expect(slideCenters[i], greaterThan(initialPillCenter.dx));
      expect(slideCenters[i], lessThan(settingsIconCenter.dx));
      if (i > 0) {
        expect(slideCenters[i], greaterThan(slideCenters[i - 1]));
      }
    }

    await tester.pumpAndSettle();
    final finalPillCenter = tester.getCenter(pillFinder);
    expect(finalPillCenter.dx, closeTo(settingsIconCenter.dx, 0.5));
  });

  testWidgets('按住滑块拖动会缩放并切换到最近的 tab', (tester) async {
    int? selected;
    await pumpBar(
      tester,
      selectedIndex: 0,
      onDestinationSelected: (index) => selected = index,
    );

    final pillFinder = find.byKey(const ValueKey('capsule_selection_pill'));
    final gesture = await tester.startGesture(tester.getCenter(pillFinder));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1.0),
    );

    await gesture.moveBy(const Offset(240, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, 1);
    final filesIconCenter = tester.getCenter(
      find.byIcon(Icons.folder_special_rounded),
    );
    expect(tester.getCenter(pillFinder).dx, closeTo(filesIconCenter.dx, 0.5));
  });
}
