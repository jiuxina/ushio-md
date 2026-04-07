// ============================================================================
// SettingsProvider 单元测试
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/utils/app_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider', () {
    late SettingsProvider provider;

    setUp(() async {
      // 模拟 SharedPreferences 初始数据
      SharedPreferences.setMockInitialValues({});
      // 模拟 FlutterSecureStorage 初始数据
      FlutterSecureStorage.setMockInitialValues({});

      provider = SettingsProvider();
      await provider.initialize();
    });

    test('默认值应正确', () {
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.fontSize, 16.0);
      expect(provider.autoSave, true);
      expect(provider.autoSaveInterval, 30);
      expect(provider.webdavUrl, isEmpty);
      expect(provider.syncFolderName, 'Ushio-MD');
      expect(provider.buttonStyleMode, AppButtonStyleMode.classic);
    });

    test('setThemeMode 应更新内存和持久化存储', () async {
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('theme_mode'), ThemeMode.dark.index);
    });

    test('setFontSize 应更新内存和持久化存储', () async {
      await provider.setFontSize(20.0);
      expect(provider.fontSize, 20.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('font_size'), 20.0);
    });

    test('setButtonStyleMode 应更新内存和持久化存储', () async {
      await provider.setButtonStyleMode(AppButtonStyleMode.softShadow);
      expect(provider.buttonStyleMode, AppButtonStyleMode.softShadow);
      expect(provider.useBorderlessButtons, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('button_style_mode'),
        AppButtonStyleMode.softShadow.name,
      );
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

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auto_sync_enabled'), true);
    });

    test('setSyncFolderName 应更新状态', () async {
      await provider.setSyncFolderName('MyFolder');
      expect(provider.syncFolderName, 'MyFolder');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sync_folder_name'), 'MyFolder');
    });

    test('编辑器背景模糊设置应更新并持久化', () async {
      await provider.setEditorBackgroundBlurEnabled(true);
      await provider.setEditorBackgroundBlur(18.0);
      expect(provider.editorBackgroundBlurEnabled, isTrue);
      expect(provider.editorBackgroundBlur, 18.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('editor_background_blur_enabled'), isTrue);
      expect(prefs.getDouble('editor_background_blur'), 18.0);
    });

    test('背景亮度设置应更新并持久化', () async {
      await provider.setBackgroundBrightness(1.25);
      await provider.setEditorBackgroundBrightness(0.8);

      expect(provider.backgroundBrightness, 1.25);
      expect(provider.editorBackgroundBrightness, 0.8);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('background_brightness'), 1.25);
      expect(prefs.getDouble('editor_background_brightness'), 0.8);
    });
  });
}
