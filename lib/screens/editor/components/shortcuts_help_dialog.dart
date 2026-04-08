/// Keyboard shortcuts help dialog.
library;

import 'dart:io';
import 'package:flutter/material.dart';

/// Shows a dialog with all available keyboard shortcuts.
void showShortcutsHelpDialog(BuildContext context) {
  final bool isMac = Platform.isMacOS;
  final String mod = isMac ? '⌘' : 'Ctrl';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
          children: [
            _buildShortcutCategory(context, '文件操作', [
              ('保存', '$mod+S'),
              ('撤销', '$mod+Z'),
              ('重做', '$mod+Shift+Z / $mod+Y'),
              ('搜索', '$mod+F'),
            ]),
            _buildShortcutCategory(context, '文本格式', [
              ('加粗', '$mod+B'),
              ('斜体', '$mod+I'),
              ('删除线', '$mod+Shift+X'),
            ]),
            _buildShortcutCategory(context, '标题', [
              ('一级标题', '$mod+1'),
              ('二级标题', '$mod+2'),
              ('三级标题', '$mod+3'),
            ]),
            _buildShortcutCategory(context, '列表与引用', [
              ('无序列表', '$mod+L'),
              ('有序列表', '$mod+Shift+L'),
              ('引用', '$mod+Q'),
            ]),
            _buildShortcutCategory(context, '代码与链接', [
              ('代码块', '$mod+K'),
              ('链接', '$mod+Shift+K'),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

Widget _buildShortcutCategory(
  BuildContext context,
  String category,
  List<(String, String)> shortcuts,
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
          title: Text(shortcut.$1),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              shortcut.$2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ),
      ),
    ],
  );
}
