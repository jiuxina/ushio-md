import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mdreader/utils/constants.dart';
import 'package:mdreader/utils/theme_tones.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  String get _root => '${Directory.current.path}/build/test-temp/appearance';

  @override
  Future<String?> getApplicationDocumentsPath() async => '$_root/documents';

  @override
  Future<String?> getApplicationSupportPath() async => '$_root/support';

  @override
  Future<String?> getTemporaryPath() async => '$_root/tmp';
}

/// 用真实 SettingsProvider + 平台 mock 构建外观页测试环境。
///
/// 两点必须注意，否则断言会不可信：
/// - SliverList 只构建视口与 cacheExtent 内的子项，测试面要拉高到能容纳整页；
/// - SettingsProvider 的写入有 500ms 防抖 Timer，pumpAndSettle 只等帧不等 Timer，
///   不冲刷的话测试结束会报 pending timer。
Future<SettingsProvider> createAppearanceSettings() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PathProviderPlatform.instance = FakePathProviderPlatform();
  final settings = SettingsProvider();
  await settings.initialize();
  return settings;
}

Future<void> pumpAppearancePage(
  WidgetTester tester,
  SettingsProvider settings,
  Widget page, {
  Brightness brightness = Brightness.light,
  Size logicalSize = const Size(400, 3000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = logicalSize * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final paper = brightness == Brightness.dark
      ? AppConstants.darkThemeSchemes[settings.darkThemeIndex]
      : AppConstants.lightThemeSchemes[settings.lightThemeIndex];
  final scheme = ThemeTones.scheme(
    themeScheme: paper,
    primary: settings.primaryColor,
    brightness: brightness,
    error: AppConstants.errorColor,
  );
  final appStyle = AppStyleTheme.resolve(
    brightness: brightness,
    colorScheme: scheme,
    backgroundColor: paper.background,
    textSecondary: scheme.onSurfaceVariant,
    buttonStyleMode: settings.buttonStyleMode,
    cardOpacity: settings.cardOpacity,
    customCardColor: settings.customCardColor,
    customIconColor: settings.customIconColor,
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        locale: const Locale('zh'),
        theme: ThemeData(
          colorScheme: scheme,
          brightness: brightness,
          scaffoldBackgroundColor: paper.background,
          textTheme: TextTheme(
            bodyMedium: TextStyle(color: settings.uiFontColorFor(brightness)),
          ),
          extensions: [appStyle],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

List<String> schemeNames({required bool dark}) =>
    (dark ? AppConstants.darkThemeSchemes : AppConstants.lightThemeSchemes)
        .map((s) => s.name)
        .toList();
