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
      expect(prefs.getString('button_style_mode'), AppButtonStyleMode.softShadow.name);
    });

    test('WebDAV 密码应存储在 SecureStorage 中', () async {
      const password = 'secret_password';
      await provider.setWebdavPassword(password);
      
      expect(provider.webdavPassword, password);
      
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

    test('setBackgroundOverlayOpacity 应更新内存和持久化存储', () async {
      await provider.setBackgroundOverlayOpacity(0.37);
      expect(provider.backgroundOverlayOpacity, 0.37);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('background_overlay_opacity'), 0.37);
    });
  });
}
