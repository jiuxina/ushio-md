import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/utils/capsule_nav_insets.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<double> readInset(WidgetTester tester, String tabBarStyle) async {
    SharedPreferences.setMockInitialValues({'tab_bar_style': tabBarStyle});
    FlutterSecureStorage.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    final provider = SettingsProvider();
    await provider.initialize();

    double value = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              value = capsuleTabBarBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return value;
  }

  testWidgets('胶囊模式返回非零底部余量', (tester) async {
    final value = await readInset(tester, 'liquidGlassCapsule');
    expect(value, greaterThan(0));
  });

  testWidgets('经典模式返回 0', (tester) async {
    final value = await readInset(tester, 'classic');
    expect(value, 0);
  });
}
