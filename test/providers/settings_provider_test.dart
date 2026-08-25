// ============================================================================
// SettingsProvider 单元测试
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/utils/app_style.dart';

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

  Future<void> flushPersist() =>
      Future<void>.delayed(const Duration(milliseconds: 600));

  group('SettingsProvider', () {
    late SettingsProvider provider;

    setUp(() async {
      // 模拟 SharedPreferences 初始数据
      SharedPreferences.setMockInitialValues({});
      // 模拟 FlutterSecureStorage 初始数据
      FlutterSecureStorage.setMockInitialValues({});
      // 模拟 path_provider，避免测试环境缺少平台实现
      PathProviderPlatform.instance = _FakePathProviderPlatform();

      provider = SettingsProvider();
      await provider.initialize();
    });

    test('默认值应正确', () {
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.fontSize, 16.0);
      expect(provider.autoSave, false);
      expect(provider.autoSaveInterval, 30);
      expect(provider.webdavUrl, isEmpty);
      expect(provider.syncFolderName, 'Ushio-MD');
      expect(provider.buttonStyleMode, AppButtonStyleMode.softShadow);
      expect(provider.tabBarStyle, AppTabBarStyleMode.classic);
      expect(provider.useCustomIconColor, isFalse);
      expect(provider.customIconColor, isNull);
    });

    test('UI文字颜色与全局图标颜色预设应和主题色调色板一致', () {
      expect(SettingsProvider.uiFontColors, same(SettingsProvider.themeColors));
      expect(
        SettingsProvider.globalIconColors,
        same(SettingsProvider.themeColors),
      );
    });

    test('setCustomIconColor 应更新内存并启用自定义颜色', () async {
      const color = Color(0xFF00BCD4);
      await provider.setCustomIconColor(color);

      expect(provider.customIconColor, color);
      expect(provider.useCustomIconColor, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('custom_icon_color'), color.toARGB32());
      expect(prefs.getBool('use_custom_icon_color'), isTrue);
    });

    test('setUseCustomIconColor 应持久化开关', () async {
      await provider.setUseCustomIconColor(true);
      expect(provider.useCustomIconColor, isTrue);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_custom_icon_color'), isTrue);
    });

    test('initialize 应加载自定义图标颜色', () async {
      const color = Color(0xFF10B981);
      SharedPreferences.setMockInitialValues({
        'use_custom_icon_color': true,
        'custom_icon_color': color.toARGB32(),
      });
      FlutterSecureStorage.setMockInitialValues({});

      final restored = SettingsProvider();
      await restored.initialize();

      expect(restored.useCustomIconColor, isTrue);
      expect(restored.customIconColor, color);
    });

    test('setThemeMode 应更新内存和持久化存储', () async {
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_mode'), ThemeMode.dark.index);
    });

    test('setFontSize 应更新内存和持久化存储', () async {
      await provider.setFontSize(20.0);
      expect(provider.fontSize, 20.0);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('font_size'), 20.0);
    });

    test('setButtonStyleMode 应更新内存和持久化存储', () async {
      await provider.setButtonStyleMode(AppButtonStyleMode.softShadow);
      expect(provider.buttonStyleMode, AppButtonStyleMode.softShadow);
      expect(provider.useBorderlessButtons, isTrue);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('button_style_mode'),
        AppButtonStyleMode.softShadow.name,
      );
    });

    test('setTabBarStyle 应更新内存和持久化存储', () async {
      await provider.setTabBarStyle(AppTabBarStyleMode.liquidGlassCapsule);
      expect(provider.tabBarStyle, AppTabBarStyleMode.liquidGlassCapsule);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('tab_bar_style'),
        AppTabBarStyleMode.liquidGlassCapsule.name,
      );
    });

    test('initialize 应加载 tab_bar_style', () async {
      SharedPreferences.setMockInitialValues({
        'tab_bar_style': 'liquidGlassCapsule',
      });
      FlutterSecureStorage.setMockInitialValues({});

      final restored = SettingsProvider();
      await restored.initialize();

      expect(restored.tabBarStyle, AppTabBarStyleMode.liquidGlassCapsule);
    });

    test('WebDAV 密码应存储在 SecureStorage 中', () async {
      const password = 'secret_password';
      await provider.setWebdavPassword(password);

      // 使用安全方法验证密码
      final creds = provider.getWebdavCredentials();
      expect(creds['password'], password);

      // 验证 SecureStorage
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'webdav_password'), password);
    });

    test('setAutoSyncEnabled 应更新状态', () async {
      await provider.setAutoSyncEnabled(true);
      expect(provider.autoSyncEnabled, true);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_sync_enabled'), true);
    });

    test('setSyncFolderName 应更新状态', () async {
      await provider.setSyncFolderName('MyFolder');
      expect(provider.syncFolderName, 'MyFolder');
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sync_folder_name'), 'MyFolder');
    });

    test('编辑器背景模糊设置应更新并持久化', () async {
      await provider.setEditorBackgroundBlurEnabled(true);
      await provider.setEditorBackgroundBlur(18.0);
      expect(provider.editorBackgroundBlurEnabled, isTrue);
      expect(provider.editorBackgroundBlur, 18.0);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('editor_background_blur_enabled'), isTrue);
      expect(prefs.getDouble('editor_background_blur'), 18.0);
    });

    test('背景亮度设置应更新并持久化', () async {
      await provider.setBackgroundBrightness(1.25);
      await provider.setEditorBackgroundBrightness(0.8);

      expect(provider.backgroundBrightness, 1.25);
      expect(provider.editorBackgroundBrightness, 0.8);
      await flushPersist();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('background_brightness'), 1.25);
      expect(prefs.getDouble('editor_background_brightness'), 0.8);
    });
  });
}
