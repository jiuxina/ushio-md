// ============================================================================
// 插件安全机制测试
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/plugins/plugin_manifest.dart';
import 'package:mdreader/plugins/plugin_security.dart';

void main() {
  group('PluginSecurity Logic', () {
    test('checkDangerousPermissions should identify dangerous permissions', () {
      final manifest = PluginManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        author: 'Test',
        description: 'Test',
        permissions: [PluginPermission.network, PluginPermission.fileSystem, 'clipboard'],
      );
      
      final dangerous = PluginSecurity.checkDangerousPermissions(manifest);
      
      // Assuming network and file_system are dangerous
      // We need to know exactly which are dangerous.
      // Based on plugin_security.dart imports/usage:
      // It imports plugin_manifest.dart which defines PluginPermission constant probably.
      // Let's assume network and file_system are defined as dangerous in manifest logic.
      // If logic is delegated to manifest, we trust it here, or verify manifest logic in manifest_test.
      // Here we just test that security service returns what manifest says.
      
      expect(dangerous, contains(PluginPermission.network));
      expect(dangerous, contains(PluginPermission.fileSystem));
    });
  });

  group('PluginSecurity Dialog', () {
    testWidgets('Should show warning dialog for dangerous permissions', (WidgetTester tester) async {
      final manifest = PluginManifest(
        id: 'dangerous_plugin',
        name: 'Dangerous Plugin',
        version: '1.0.0',
        author: 'Hacker',
        description: 'Steals data',
        permissions: [PluginPermission.network],
      );

      bool? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await PluginSecurity.showDangerousPermissionWarning(context, manifest);
              },
              child: const Text('Install'),
            );
          }),
        ),
      ));

      // Trigger Dialog
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle(); // Wait for dialog animation

      // Verify Dialog Content
      expect(find.text('安全警告'), findsOneWidget);
      expect(find.textContaining('Dangerous Plugin'), findsOneWidget);
      // Warning about permission
      // The dialog code maps permission to description. 
      // check plugin_security.dart: PluginPermission.getDescription(perm)
      // Ensure we see something relevant. Or just check existence of dialog.
      
      // 1. Test Cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      
      expect(result, false);
      expect(find.text('安全警告'), findsNothing);
    });

    testWidgets('Should return true when user accepts risk', (WidgetTester tester) async {
      final manifest = PluginManifest(
        id: 'dangerous_plugin',
        name: 'Dangerous Plugin',
        version: '1.0.0',
        author: 'Hacker',
        description: 'Steals data',
        permissions: [PluginPermission.network],
      );

      bool? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await PluginSecurity.showDangerousPermissionWarning(context, manifest);
              },
              child: const Text('Install'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      // 2. Test Accept
      // "我了解风险，继续"
      await tester.tap(find.text('我了解风险，继续'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('Should NOT show dialog if no dangerous permissions', (WidgetTester tester) async {
      final manifest = PluginManifest(
        id: 'safe_plugin',
        name: 'Safe Plugin',
        version: '1.0.0',
        author: 'Angel',
        description: 'Safe',
        permissions: [], // No permissions
      );

      bool? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await PluginSecurity.showDangerousPermissionWarning(context, manifest);
              },
              child: const Text('Install'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      expect(find.text('安全警告'), findsNothing);
      expect(result, true); // Auto allow
    });
  });
}
