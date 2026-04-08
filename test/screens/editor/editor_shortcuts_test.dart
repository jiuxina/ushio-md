// ============================================================================
// 编辑器快捷键测试
// ============================================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ushio_md/screens/editor/editor_shortcuts.dart';

void main() {
  group('EditorShortcuts', () {
    group('platform detection', () {
      test('isMac returns correct value', () {
        expect(EditorShortcuts.isMac, isA<bool>());
      });

      test('modifierSymbol returns correct symbol', () {
        final symbol = EditorShortcuts.modifierSymbol;
        expect(symbol, isA<String>());
        expect(symbol.isNotEmpty, isTrue);
        expect(symbol == '⌘' || symbol == 'Ctrl', isTrue);
      });
    });

    group('getAllShortcuts', () {
      test('returns non-empty list', () {
        final shortcuts = EditorShortcuts.getAllShortcuts();
        expect(shortcuts, isNotEmpty);
      });

      test('contains essential shortcuts', () {
        final shortcuts = EditorShortcuts.getAllShortcuts();
        final names = shortcuts.map((s) => s.name).toList();

        expect(names.contains('保存'), isTrue);
        expect(names.contains('撤销'), isTrue);
        expect(names.contains('重做'), isTrue);
        expect(names.contains('搜索'), isTrue);
        expect(names.contains('加粗'), isTrue);
        expect(names.contains('斜体'), isTrue);
      });

      test('each shortcut has valid properties', () {
        final shortcuts = EditorShortcuts.getAllShortcuts();

        for (final shortcut in shortcuts) {
          expect(shortcut.name, isNotEmpty);
          expect(shortcut.keyCombination, isNotEmpty);
          expect(shortcut.description, isNotEmpty);
        }
      });
    });

    group('getShortcutsByCategory', () {
      test('returns categorized shortcuts', () {
        final categories = EditorShortcuts.getShortcutsByCategory();

        expect(categories, isNotEmpty);
        expect(categories.keys.contains('文件操作'), isTrue);
        expect(categories.keys.contains('文本格式'), isTrue);
        expect(categories.keys.contains('标题'), isTrue);
        expect(categories.keys.contains('列表与引用'), isTrue);
        expect(categories.keys.contains('代码与链接'), isTrue);
      });

      test('all shortcuts are categorized', () {
        final all = EditorShortcuts.getAllShortcuts();
        final categories = EditorShortcuts.getShortcutsByCategory();

        int categorized = 0;
        for (final shortcuts in categories.values) {
          categorized += shortcuts.length;
        }

        expect(categorized, equals(all.length));
      });
    });

    group('buildBindings', () {
      test('returns map with required shortcuts', () {
        final bindings = EditorShortcuts.buildBindings(
          onSave: () {},
          onUndo: () {},
          onRedo: () {},
          onSearch: () {},
          onBold: () {},
          onItalic: () {},
          onStrikethrough: () {},
          onHeading1: () {},
          onHeading2: () {},
          onHeading3: () {},
          onBulletList: () {},
          onOrderedList: () {},
          onBlockquote: () {},
          onCodeBlock: () {},
          onLink: () {},
        );

        expect(bindings, isNotEmpty);

        for (final callback in bindings.values) {
          expect(callback, isA<Function>());
        }
      });

      test('includes optional callbacks when provided', () {
        final bindings = EditorShortcuts.buildBindings(
          onSave: () {},
          onUndo: () {},
          onRedo: () {},
          onSearch: () {},
          onBold: () {},
          onItalic: () {},
          onStrikethrough: () {},
          onHeading1: () {},
          onHeading2: () {},
          onHeading3: () {},
          onBulletList: () {},
          onOrderedList: () {},
          onBlockquote: () {},
          onCodeBlock: () {},
          onLink: () {},
          onEscape: () {},
          onNextSearchMatch: () {},
          onPrevSearchMatch: () {},
        );

        expect(
          bindings.containsKey(const SingleActivator(LogicalKeyboardKey.escape)),
          isTrue,
        );
        expect(
          bindings.containsKey(const SingleActivator(LogicalKeyboardKey.f3)),
          isTrue,
        );
        expect(
          bindings.containsKey(
            const SingleActivator(LogicalKeyboardKey.f3, shift: true),
          ),
          isTrue,
        );
      });
    });
  });

  group('buildShortcutBindings (simplified)', () {
    test('returns map with required shortcuts', () {
      final bindings = buildShortcutBindings(
        onSave: () {},
        onUndo: () {},
        onRedo: () {},
        onSearch: () {},
        onApplyAction: (_) {},
      );

      expect(bindings, isNotEmpty);
      expect(bindings.length, greaterThanOrEqualTo(14));
    });

    test('callbacks are invokable', () {
      var actionCalled = false;
      MarkdownToolbarAction? capturedAction;

      final bindings = buildShortcutBindings(
        onSave: () {},
        onUndo: () {},
        onRedo: () {},
        onSearch: () {},
        onApplyAction: (action) {
          actionCalled = true;
          capturedAction = action;
        },
      );

      // Find a binding and invoke it
      final boldBinding = bindings.entries.firstWhere(
        (e) => e.key.toString().contains('KeyB'),
        orElse: () => bindings.entries.first,
      );

      boldBinding.value();
      expect(actionCalled, isTrue);
    });
  });

  group('ShortcutInfo', () {
    test('creates with required parameters', () {
      const info = ShortcutInfo(
        name: '测试快捷键',
        keyCombination: 'Ctrl+T',
        description: '这是一个测试快捷键',
      );

      expect(info.name, equals('测试快捷键'));
      expect(info.keyCombination, equals('Ctrl+T'));
      expect(info.description, equals('这是一个测试快捷键'));
    });
  });
}
