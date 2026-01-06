// ============================================================================
// 插件清单解析测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/plugins/plugin_manifest.dart';

void main() {
  group('PluginManifest', () {
    test('should parse valid JSON', () {
      final json = {
        'id': 'test.plugin',
        'name': 'Test Plugin',
        'version': '1.0.0',
        'author': 'Test Author',
        'description': 'A test plugin',
        'permissions': ['toolbar', 'theme'],
        'extensions': {
          'toolbar': [
            {'id': 'btn1', 'icon': 'code', 'tooltip': 'Test'}
          ]
        }
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.id, 'test.plugin');
      expect(manifest.name, 'Test Plugin');
      expect(manifest.version, '1.0.0');
      expect(manifest.author, 'Test Author');
      expect(manifest.permissions.length, 2);
      expect(manifest.isValid, true);
    });

    test('should handle missing optional fields', () {
      final json = {
        'id': 'minimal.plugin',
        'name': 'Minimal',
        'version': '1.0.0',
        'author': 'Author',
        'description': ''
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.id, 'minimal.plugin');
      expect(manifest.iconPath, isNull);
      expect(manifest.signature, isNull);
      expect(manifest.permissions, isEmpty);
      expect(manifest.extensions, isEmpty);
      expect(manifest.isValid, true);
    });

    test('should detect invalid manifest', () {
      final json = <String, dynamic>{
        'name': 'No ID',
        'version': '1.0.0'
      };

      final manifest = PluginManifest.fromJson(json);

      expect(manifest.isValid, false);
    });
  });

  group('PluginPermission', () {
    test('should identify dangerous permissions', () {
      expect(PluginPermission.isDangerous('cloud'), true);
      expect(PluginPermission.isDangerous('network'), true);
      expect(PluginPermission.isDangerous('filesystem'), true);
      expect(PluginPermission.isDangerous('file_actions'), true);
    });

    test('should identify safe permissions', () {
      expect(PluginPermission.isDangerous('toolbar'), false);
      expect(PluginPermission.isDangerous('theme'), false);
      expect(PluginPermission.isDangerous('preview'), false);
    });

    test('should get permission description', () {
      expect(PluginPermission.getDescription('toolbar'), '工具栏扩展');
      expect(PluginPermission.getDescription('cloud'), '云服务访问（危险）');
    });
  });

  group('PluginManifest.hasDangerousPermissions', () {
    test('should detect dangerous permissions in manifest', () {
      final manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
        description: '',
        permissions: ['toolbar', 'cloud', 'theme'],
      );

      expect(manifest.hasDangerousPermissions, true);
      expect(manifest.dangerousPermissions, ['cloud']);
    });

    test('should return false for safe permissions only', () {
      final manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        author: 'Author',
        description: '',
        permissions: ['toolbar', 'theme'],
      );

      expect(manifest.hasDangerousPermissions, false);
      expect(manifest.dangerousPermissions, isEmpty);
    });
  });

  group('MarketplacePluginInfo', () {
    test('should parse marketplace plugin JSON', () {
      final json = {
        'id': 'market.plugin',
        'name': 'Market Plugin',
        'version': '2.0.0',
        'author': 'Market Author',
        'description': 'From marketplace',
        'downloadUrl': 'https://example.com/plugin.zip',
        'downloadCount': 100,
        'rating': 4.5,
        'permissions': ['toolbar', 'network']
      };

      final plugin = MarketplacePluginInfo.fromJson(json);

      expect(plugin.id, 'market.plugin');
      expect(plugin.downloadCount, 100);
      expect(plugin.rating, 4.5);
      expect(plugin.hasDangerousPermissions, true);
    });
  });
}
