// ============================================================================
// 扩展点解析测试
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/plugins/extensions/toolbar_extension.dart';
import 'package:mdreader/plugins/extensions/theme_extension.dart';
import 'package:mdreader/plugins/extensions/preview_extension.dart';
import 'package:mdreader/plugins/extensions/export_extension.dart';

void main() {
  group('ToolbarButtonExtension', () {
    test('should parse toolbar button JSON', () {
      final json = {
        'id': 'test-btn',
        'icon': 'code',
        'tooltip': 'Insert Code',
        'insertBefore': '```\n',
        'insertAfter': '\n```',
        'priority': 10
      };

      final button = ToolbarButtonExtension.fromJson(json, 'test-plugin');

      expect(button.buttonId, 'test-btn');
      expect(button.pluginId, 'test-plugin');
      expect(button.icon, 'code');
      expect(button.tooltip, 'Insert Code');
      expect(button.insertBefore, '```\n');
      expect(button.insertAfter, '\n```');
      expect(button.priority, 10);
    });

    test('should handle default values', () {
      final json = <String, dynamic>{
        'id': 'minimal-btn'
      };

      final button = ToolbarButtonExtension.fromJson(json, 'plugin');

      expect(button.insertBefore, '');
      expect(button.insertAfter, '');
      expect(button.priority, 100);
      expect(button.group, isNull);
    });
  });

  group('PluginThemeExtension', () {
    test('should parse theme JSON', () {
      final json = {
        'id': 'dracula',
        'name': 'Dracula Theme',
        'light': {
          'primary': '#BD93F9',
          'secondary': '#FF79C6'
        },
        'dark': {
          'primary': '#BD93F9',
          'surface': '#44475A'
        }
      };

      final theme = PluginThemeExtension.fromJson(json, 'theme-plugin');

      expect(theme.themeId, 'dracula');
      expect(theme.themeName, 'Dracula Theme');
      expect(theme.lightColors, isNotNull);
      expect(theme.darkColors, isNotNull);
    });
  });

  group('PluginPreviewExtension', () {
    test('should parse preview JSON', () {
      final json = {
        'id': 'custom-preview',
        'css': 'h1 { color: red; }',
        'codeTheme': 'monokai',
        'lineHeight': 1.8
      };

      final preview = PluginPreviewExtension.fromJson(json, 'preview-plugin');

      expect(preview.customCss, 'h1 { color: red; }');
      expect(preview.codeTheme, 'monokai');
      expect(preview.lineHeight, 1.8);
    });
  });

  group('PluginExportExtension', () {
    test('should parse export JSON', () {
      final json = {
        'id': 'latex',
        'name': 'LaTeX',
        'extension': 'tex',
        'template': 'assets/template.tex',
        'mimeType': 'application/x-latex'
      };

      final export = PluginExportExtension.fromJson(json, 'export-plugin');

      expect(export.formatId, 'latex');
      expect(export.formatName, 'LaTeX');
      expect(export.fileExtension, 'tex');
      expect(export.templatePath, 'assets/template.tex');
    });
  });
}
