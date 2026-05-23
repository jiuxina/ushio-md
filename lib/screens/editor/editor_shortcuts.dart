// ============================================================================
// 编辑器快捷键管理
//
// 定义和处理编辑器的键盘快捷键，支持 macOS 和其他平台的差异。
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/markdown_toolbar.dart';

/// 快捷键操作类型
enum EditorShortcutAction {
  save,
  undo,
  redo,
  search,
  bold,
  italic,
  strikethrough,
  heading1,
  heading2,
  heading3,
  bulletList,
  orderedList,
  blockquote,
  codeBlock,
  link,
}

/// 快捷键信息
class ShortcutInfo {
  final String name;
  final String keyCombination;
  final String description;

  const ShortcutInfo({
    required this.name,
    required this.keyCombination,
    required this.description,
  });
}

/// 编辑器快捷键管理器
///
/// 提供快捷键绑定和帮助信息的生成
class EditorShortcuts {
  /// 判断是否是 macOS
  static bool get isMac => Platform.isMacOS;

  /// 获取修饰键符号
  static String get modifierSymbol => isMac ? '⌘' : 'Ctrl';

  /// 构建快捷键绑定
  ///
  /// 返回快捷键激活器到回调的映射
  static Map<ShortcutActivator, VoidCallback> buildBindings({
    required VoidCallback onSave,
    required VoidCallback onUndo,
    required VoidCallback onRedo,
    required VoidCallback onSearch,
    required VoidCallback onBold,
    required VoidCallback onItalic,
    required VoidCallback onStrikethrough,
    required VoidCallback onHeading1,
    required VoidCallback onHeading2,
    required VoidCallback onHeading3,
    required VoidCallback onBulletList,
    required VoidCallback onOrderedList,
    required VoidCallback onBlockquote,
    required VoidCallback onCodeBlock,
    required VoidCallback onLink,
    VoidCallback? onEscape,
    VoidCallback? onNextSearchMatch,
    VoidCallback? onPrevSearchMatch,
  }) {
    return <ShortcutActivator, VoidCallback>{
      // 保存: Ctrl+S / Cmd+S
      SingleActivator(LogicalKeyboardKey.keyS, control: !isMac, meta: isMac):
          onSave,

      // 撤销: Ctrl+Z / Cmd+Z
      SingleActivator(LogicalKeyboardKey.keyZ, control: !isMac, meta: isMac):
          onUndo,

      // 重做: Ctrl+Shift+Z / Cmd+Shift+Z
      SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !isMac,
        meta: isMac,
        shift: true,
      ): onRedo,

      // 重做（备用）: Ctrl+Y / Cmd+Y
      SingleActivator(LogicalKeyboardKey.keyY, control: !isMac, meta: isMac):
          onRedo,

      // 搜索: Ctrl+F / Cmd+F
      SingleActivator(LogicalKeyboardKey.keyF, control: !isMac, meta: isMac):
          onSearch,

      // 加粗: Ctrl+B / Cmd+B
      SingleActivator(LogicalKeyboardKey.keyB, control: !isMac, meta: isMac):
          onBold,

      // 斜体: Ctrl+I / Cmd+I
      SingleActivator(LogicalKeyboardKey.keyI, control: !isMac, meta: isMac):
          onItalic,

      // 删除线: Ctrl+Shift+X / Cmd+Shift+X
      SingleActivator(
        LogicalKeyboardKey.keyX,
        control: !isMac,
        meta: isMac,
        shift: true,
      ): onStrikethrough,

      // 一级标题: Ctrl+1 / Cmd+1
      SingleActivator(LogicalKeyboardKey.digit1, control: !isMac, meta: isMac):
          onHeading1,

      // 二级标题: Ctrl+2 / Cmd+2
      SingleActivator(LogicalKeyboardKey.digit2, control: !isMac, meta: isMac):
          onHeading2,

      // 三级标题: Ctrl+3 / Cmd+3
      SingleActivator(LogicalKeyboardKey.digit3, control: !isMac, meta: isMac):
          onHeading3,

      // 无序列表: Ctrl+L / Cmd+L
      SingleActivator(LogicalKeyboardKey.keyL, control: !isMac, meta: isMac):
          onBulletList,

      // 有序列表: Ctrl+Shift+L / Cmd+Shift+L
      SingleActivator(
        LogicalKeyboardKey.keyL,
        control: !isMac,
        meta: isMac,
        shift: true,
      ): onOrderedList,

      // 引用: Ctrl+Q / Cmd+Q
      SingleActivator(LogicalKeyboardKey.keyQ, control: !isMac, meta: isMac):
          onBlockquote,

      // 代码块: Ctrl+K / Cmd+K
      SingleActivator(LogicalKeyboardKey.keyK, control: !isMac, meta: isMac):
          onCodeBlock,

      // 链接: Ctrl+Shift+K / Cmd+Shift+K
      SingleActivator(
        LogicalKeyboardKey.keyK,
        control: !isMac,
        meta: isMac,
        shift: true,
      ): onLink,

      // Escape: 关闭搜索栏
      if (onEscape != null)
        const SingleActivator(LogicalKeyboardKey.escape): onEscape,

      // F3: 下一个搜索匹配
      if (onNextSearchMatch != null)
        const SingleActivator(LogicalKeyboardKey.f3): onNextSearchMatch,

      // Shift+F3: 上一个搜索匹配
      if (onPrevSearchMatch != null)
        SingleActivator(LogicalKeyboardKey.f3, shift: true): onPrevSearchMatch,
    };
  }

  /// 获取所有快捷键的帮助信息
  static List<ShortcutInfo> getAllShortcuts() {
    final mod = modifierSymbol;

    return [
      // 文件操作
      ShortcutInfo(name: '保存', keyCombination: '$mod+S', description: '保存当前文件'),
      ShortcutInfo(
        name: '撤销',
        keyCombination: '$mod+Z',
        description: '撤销上一步操作',
      ),
      ShortcutInfo(
        name: '重做',
        keyCombination: '$mod+Shift+Z / $mod+Y',
        description: '重做已撤销的操作',
      ),
      ShortcutInfo(name: '搜索', keyCombination: '$mod+F', description: '打开搜索栏'),

      // 文本格式
      ShortcutInfo(name: '加粗', keyCombination: '$mod+B', description: '切换粗体格式'),
      ShortcutInfo(name: '斜体', keyCombination: '$mod+I', description: '切换斜体格式'),
      ShortcutInfo(
        name: '删除线',
        keyCombination: '$mod+Shift+X',
        description: '切换删除线格式',
      ),

      // 标题
      ShortcutInfo(
        name: '一级标题',
        keyCombination: '$mod+1',
        description: '设置为一级标题',
      ),
      ShortcutInfo(
        name: '二级标题',
        keyCombination: '$mod+2',
        description: '设置为二级标题',
      ),
      ShortcutInfo(
        name: '三级标题',
        keyCombination: '$mod+3',
        description: '设置为三级标题',
      ),

      // 列表与引用
      ShortcutInfo(
        name: '无序列表',
        keyCombination: '$mod+L',
        description: '插入无序列表',
      ),
      ShortcutInfo(
        name: '有序列表',
        keyCombination: '$mod+Shift+L',
        description: '插入有序列表',
      ),
      ShortcutInfo(name: '引用', keyCombination: '$mod+Q', description: '插入引用块'),

      // 代码与链接
      ShortcutInfo(name: '代码块', keyCombination: '$mod+K', description: '插入代码块'),
      ShortcutInfo(
        name: '链接',
        keyCombination: '$mod+Shift+K',
        description: '插入链接',
      ),
    ];
  }

  /// 按分类获取快捷键
  static Map<String, List<ShortcutInfo>> getShortcutsByCategory() {
    final all = getAllShortcuts();

    return {
      '文件操作': all.sublist(0, 4),
      '文本格式': all.sublist(4, 7),
      '标题': all.sublist(7, 10),
      '列表与引用': all.sublist(10, 13),
      '代码与链接': all.sublist(13, 15),
    };
  }
}

/// 构建编辑器快捷键绑定（简化版）
///
/// 直接接收一个 applyAction 回调来处理工具栏操作
Map<ShortcutActivator, VoidCallback> buildShortcutBindings({
  required VoidCallback onSave,
  required VoidCallback onUndo,
  required VoidCallback onRedo,
  required VoidCallback onSearch,
  required void Function(MarkdownToolbarAction) onApplyAction,
  VoidCallback? onEscape,
  VoidCallback? onNextSearchMatch,
  VoidCallback? onPrevSearchMatch,
}) {
  return EditorShortcuts.buildBindings(
    onSave: onSave,
    onUndo: onUndo,
    onRedo: onRedo,
    onSearch: onSearch,
    onBold: () => onApplyAction(MarkdownToolbarAction.bold),
    onItalic: () => onApplyAction(MarkdownToolbarAction.italic),
    onStrikethrough: () => onApplyAction(MarkdownToolbarAction.strikethrough),
    onHeading1: () => onApplyAction(MarkdownToolbarAction.heading1),
    onHeading2: () => onApplyAction(MarkdownToolbarAction.heading2),
    onHeading3: () => onApplyAction(MarkdownToolbarAction.heading3),
    onBulletList: () => onApplyAction(MarkdownToolbarAction.bulletList),
    onOrderedList: () => onApplyAction(MarkdownToolbarAction.orderedList),
    onBlockquote: () => onApplyAction(MarkdownToolbarAction.blockquote),
    onCodeBlock: () => onApplyAction(MarkdownToolbarAction.codeBlock),
    onLink: () => onApplyAction(MarkdownToolbarAction.link),
    onEscape: onEscape,
    onNextSearchMatch: onNextSearchMatch,
    onPrevSearchMatch: onPrevSearchMatch,
  );
}

/// 快捷键帮助对话框
class ShortcutHelpDialog extends StatelessWidget {
  const ShortcutHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = EditorShortcuts.getShortcutsByCategory();

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.keyboard,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Text('快捷键'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: categories.entries
              .map((entry) => _buildCategory(context, entry.key, entry.value))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context,
    String category,
    List<ShortcutInfo> shortcuts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...shortcuts.map(
          (shortcut) => ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            title: Text(shortcut.name),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                shortcut.keyCombination,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
