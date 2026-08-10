import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/my_files_service.dart';
import '../utils/app_style.dart';
import '../utils/responsive_layout.dart';

enum MarkdownToolbarAction {
  undo,
  redo,
  bold,
  italic,
  strikethrough,
  heading1,
  heading2,
  heading3,
  bulletList,
  orderedList,
  taskList,
  blockquote,
  inlineCode,
  codeBlock,
  link,
  image,
  horizontalRule,
  table,
  search,
}

/// Markdown editing toolbar with beautiful gradient buttons
class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final UndoHistoryController? undoController; // 撤回重做控制器
  final bool? canUndo;
  final bool? canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final String? filePath; // Path to the markdown file being edited
  final VoidCallback? onSearchPressed; // 搜索按钮回调
  final Future<void> Function(MarkdownToolbarAction action)? onAction;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.undoController,
    this.canUndo,
    this.canRedo,
    this.onUndo,
    this.onRedo,
    this.filePath,
    this.onSearchPressed,
    this.onAction,
  });

  void _runAction(MarkdownToolbarAction action, VoidCallback fallback) {
    final handler = onAction;
    if (handler != null) {
      unawaited(handler(action));
      return;
    }
    fallback();
  }

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final showCustomUndoRedo =
        undoController == null && onUndo != null && onRedo != null;
    // Increase toolbar height on touch devices
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    final isTouchDevice =
        !isDesktop && MediaQuery.of(context).size.shortestSide < 600;
    final toolbarHeight = isTouchDevice ? 64.0 : 56.0;

    return Container(
      height: toolbarHeight,
      decoration: BoxDecoration(
        color: appStyle.scaledSurfaceColor(
          Theme.of(context).colorScheme,
          alpha: 0.95,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isDesktop ? 12 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: isTouchDevice ? 10 : 6,
        ),
        children: [
          // 撤回重做按钮组
          if (undoController != null)
            _ToolbarButtonGroup(
              children: [
                ValueListenableBuilder<UndoHistoryValue>(
                  valueListenable: undoController!,
                  builder: (context, value, child) {
                    return _ToolbarButton(
                      icon: Icons.undo,
                      tooltip: '撤回',
                      enabled: value.canUndo,
                      onPressed: () => _runAction(
                        MarkdownToolbarAction.undo,
                        () => undoController!.undo(),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<UndoHistoryValue>(
                  valueListenable: undoController!,
                  builder: (context, value, child) {
                    return _ToolbarButton(
                      icon: Icons.redo,
                      tooltip: '重做',
                      enabled: value.canRedo,
                      onPressed: () => _runAction(
                        MarkdownToolbarAction.redo,
                        () => undoController!.redo(),
                      ),
                    );
                  },
                ),
              ],
            ),
          if (showCustomUndoRedo)
            _ToolbarButtonGroup(
              children: [
                _ToolbarButton(
                  icon: Icons.undo,
                  tooltip: '撤回',
                  enabled: canUndo ?? false,
                  onPressed: () =>
                      _runAction(MarkdownToolbarAction.undo, onUndo!),
                ),
                _ToolbarButton(
                  icon: Icons.redo,
                  tooltip: '重做',
                  enabled: canRedo ?? false,
                  onPressed: () =>
                      _runAction(MarkdownToolbarAction.redo, onRedo!),
                ),
              ],
            ),
          if (undoController != null || showCustomUndoRedo)
            _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.format_bold,
                tooltip: '粗体',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.bold,
                  () => _wrapSelection('**', '**'),
                ),
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                tooltip: '斜体',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.italic,
                  () => _wrapSelection('*', '*'),
                ),
              ),
              _ToolbarButton(
                icon: Icons.format_strikethrough,
                tooltip: '删除线',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.strikethrough,
                  () => _wrapSelection('~~', '~~'),
                ),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.looks_one,
                tooltip: '标题 1',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.heading1,
                  () => _insertAtLineStart('# '),
                ),
              ),
              _ToolbarButton(
                icon: Icons.looks_two,
                tooltip: '标题 2',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.heading2,
                  () => _insertAtLineStart('## '),
                ),
              ),
              _ToolbarButton(
                icon: Icons.looks_3,
                tooltip: '标题 3',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.heading3,
                  () => _insertAtLineStart('### '),
                ),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.format_list_bulleted,
                tooltip: '无序列表',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.bulletList,
                  () => _insertAtLineStart('- '),
                ),
              ),
              _ToolbarButton(
                icon: Icons.format_list_numbered,
                tooltip: '有序列表',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.orderedList,
                  () => _insertAtLineStart('1. '),
                ),
              ),
              _ToolbarButton(
                icon: Icons.check_box_outlined,
                tooltip: '任务列表',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.taskList,
                  () => _insertAtLineStart('- [ ] '),
                ),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.format_quote,
                tooltip: '引用',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.blockquote,
                  () => _insertAtLineStart('> '),
                ),
              ),
              _ToolbarButton(
                icon: Icons.code,
                tooltip: '行内代码',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.inlineCode,
                  () => _wrapSelection('`', '`'),
                ),
              ),
              _ToolbarButton(
                icon: Icons.data_object,
                tooltip: '代码块',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.codeBlock,
                  _insertCodeBlock,
                ),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.link,
                tooltip: '链接',
                onPressed: () =>
                    _runAction(MarkdownToolbarAction.link, _insertLink),
              ),
              _ToolbarButton(
                icon: Icons.image,
                tooltip: '图片',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.image,
                  () => _showImageDialog(context),
                ),
              ),
              _ToolbarButton(
                icon: Icons.horizontal_rule,
                tooltip: '分割线',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.horizontalRule,
                  () => _insertText('\n---\n'),
                ),
              ),
              _ToolbarButton(
                icon: Icons.table_chart,
                tooltip: '表格',
                onPressed: () => _runAction(
                  MarkdownToolbarAction.table,
                  () => _showTableDialog(context),
                ),
              ),
            ],
          ),
          // 搜索按钮
          if (onSearchPressed != null) ...[
            _buildDivider(context),
            _ToolbarButtonGroup(
              children: [
                _ToolbarButton(
                  icon: Icons.search,
                  tooltip: '搜索',
                  onPressed: () => _runAction(
                    MarkdownToolbarAction.search,
                    onSearchPressed!,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
    );
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isCollapsed) {
      final newText = '$prefix文本$suffix';
      controller.text =
          text.substring(0, selection.start) +
          newText +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + 2,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = '$prefix$selectedText$suffix';
      controller.text =
          text.substring(0, selection.start) +
          newText +
          text.substring(selection.end);
      controller.selection = TextSelection.collapsed(
        offset: selection.start + newText.length,
      );
    }
  }

  void _insertAtLineStart(String prefix) {
    final text = controller.text;
    final selection = controller.selection;

    int lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    controller.text =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    controller.selection = TextSelection.collapsed(
      offset: selection.start + prefix.length,
    );
  }

  void _insertText(String textToInsert) {
    final text = controller.text;
    final selection = controller.selection;

    controller.text =
        text.substring(0, selection.start) +
        textToInsert +
        text.substring(selection.end);
    controller.selection = TextSelection.collapsed(
      offset: selection.start + textToInsert.length,
    );
  }

  void _insertLink() {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isCollapsed) {
      const linkText = '[链接文本](https://example.com)';
      controller.text =
          text.substring(0, selection.start) +
          linkText +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + 1,
        extentOffset: selection.start + 5,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final linkText = '[$selectedText](https://example.com)';
      controller.text =
          text.substring(0, selection.start) +
          linkText +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + selectedText.length + 3,
        extentOffset: selection.start + selectedText.length + 22,
      );
    }
  }

  void _showImageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '插入图片',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildImageOption(
              context,
              icon: Icons.link,
              label: '输入图片链接',
              subtitle: '使用网络图片 URL',
              onTap: () {
                Navigator.pop(context);
                _showImageUrlDialog(context);
              },
            ),
            const SizedBox(height: 12),
            _buildImageOption(
              context,
              icon: Icons.folder_open,
              label: '从设备选择',
              subtitle: '选择本地图片文件',
              onTap: () {
                Navigator.pop(context);
                _pickImageFile(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showImageUrlDialog(BuildContext context) async {
    final urlController = TextEditingController();
    final descController = TextEditingController(text: '图片描述');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.link, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            const Text('插入图片链接'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '图片 URL',
                  hintText: 'https://example.com/image.png',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: '图片描述 (Alt 文本)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'url': urlController.text,
                  'desc': descController.text,
                });
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('插入'),
          ),
        ],
      ),
    );

    if (result != null) {
      _insertImageWithUrl(result['url']!, result['desc']!);
    }
  }

  Future<void> _pickImageFile(BuildContext context) async {
    if (filePath == null) {
      // No document path — pick the image and use its absolute path
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          final imagePath = file.path ?? file.name;
          _insertImageWithUrl(imagePath, file.name);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
        }
      }
      return;
    }

    // Document path is known — pick image and copy to images/ subdirectory
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final imagePath = file.path ?? file.name;

        // Try to copy the image to the document's images/ directory
        try {
          final myFilesService = MyFilesService();
          final relativePath = await myFilesService.copyImageToDocument(
            imagePath,
            filePath!,
          );
          _insertImageWithUrl(relativePath, file.name);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green),
                    const SizedBox(width: 12),
                    const Text('图片已复制到 images 文件夹'),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } catch (e) {
          // Copy failed (e.g. permission issue) — fall back to absolute path
          _insertImageWithUrl(imagePath, file.name);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('图片路径已插入（复制到 images 文件夹失败: $e）'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  void _insertImageWithUrl(String url, String description) {
    final text = controller.text;
    final selection = controller.selection;

    final imageText = '![$description]($url)';
    controller.text =
        text.substring(0, selection.start) +
        imageText +
        text.substring(selection.end);
    controller.selection = TextSelection.collapsed(
      offset: selection.start + imageText.length,
    );
  }

  void _insertCodeBlock() {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isCollapsed) {
      const codeBlock = '\n```\n代码\n```\n';
      controller.text =
          text.substring(0, selection.start) +
          codeBlock +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + 5,
        extentOffset: selection.start + 7,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final codeBlock = '\n```\n$selectedText\n```\n';
      controller.text =
          text.substring(0, selection.start) +
          codeBlock +
          text.substring(selection.end);
      controller.selection = TextSelection.collapsed(
        offset: selection.start + codeBlock.length,
      );
    }
  }

  Future<void> _showTableDialog(BuildContext context) async {
    int rows = 2;
    int cols = 3;
    List<List<String>> cells = List.generate(
      rows,
      (r) => List.generate(cols, (c) => r == 0 ? '列${c + 1}' : '内容'),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.table_chart,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  const Text('插入表格'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row and column controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStepper(
                          label: '行',
                          value: rows,
                          onDecrease: rows > 1
                              ? () {
                                  setDialogState(() {
                                    rows--;
                                    cells.removeLast();
                                  });
                                }
                              : null,
                          onIncrease: rows < 20
                              ? () {
                                  setDialogState(() {
                                    rows++;
                                    cells.add(List.generate(cols, (_) => '内容'));
                                  });
                                }
                              : null,
                        ),
                        _buildStepper(
                          label: '列',
                          value: cols,
                          onDecrease: cols > 1
                              ? () {
                                  setDialogState(() {
                                    cols--;
                                    for (final row in cells) {
                                      if (row.length > cols) row.removeLast();
                                    }
                                  });
                                }
                              : null,
                          onIncrease: cols < 10
                              ? () {
                                  setDialogState(() {
                                    cols++;
                                    for (final row in cells) {
                                      row.add('内容');
                                    }
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Visual preview
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildTablePreview(context, cells),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Paste from Excel button
                    TextButton.icon(
                      icon: const Icon(Icons.paste, size: 18),
                      label: const Text('从剪贴板粘贴 Excel 数据'),
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text == null) return;

                        // Parse tab-separated data (Excel copy format)
                        final lines = data!.text!.split('\n');
                        final newCells = lines
                            .where((line) => line.trim().isNotEmpty)
                            .map((line) => line.split('\t'))
                            .toList();

                        if (newCells.isNotEmpty && newCells[0].isNotEmpty) {
                          setDialogState(() {
                            cells.clear();
                            cells.addAll(newCells);
                            rows = cells.length;
                            cols = cells.isNotEmpty ? cells[0].length : 1;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('插入'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      _insertTableFromCells(cells);
    }
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: onDecrease,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onIncrease,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildTablePreview(BuildContext context, List<List<String>> cells) {
    if (cells.isEmpty || cells[0].isEmpty) {
      return const SizedBox.shrink();
    }

    return Table(
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: Map.fromEntries(
        List.generate(
          cells[0].length,
          (i) => MapEntry(i, const FixedColumnWidth(60)),
        ),
      ),
      children: cells.map((row) {
        return TableRow(
          children: row.map((cell) {
            return Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                cell,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  void _insertTableFromCells(List<List<String>> cells) {
    if (cells.isEmpty || cells[0].isEmpty) return;

    final text = controller.text;
    final selection = controller.selection;

    // Build markdown table
    final cols = cells[0].length;
    final header = '| ${cells[0].join(' | ')} |';
    final separator = '| ${List.generate(cols, (_) => '-----').join(' | ')} |';
    final dataRows = cells
        .skip(1)
        .map((row) => '| ${row.join(' | ')} |')
        .join('\n');

    final table = '\n$header\n$separator\n$dataRows\n\n';

    controller.text =
        text.substring(0, selection.start) +
        table +
        text.substring(selection.end);
    controller.selection = TextSelection.collapsed(
      offset: selection.start + table.length,
    );
  }

  void _insertTable({int rows = 2, int cols = 3}) {
    final text = controller.text;
    final selection = controller.selection;

    // Header row
    final header = '| ${List.generate(cols, (i) => '列${i + 1}').join(' | ')} |';
    // Separator row
    final separator = '| ${List.generate(cols, (_) => '-----').join(' | ')} |';
    // Data rows
    final dataRow = '| ${List.generate(cols, (_) => '内容').join(' | ')} |';
    final dataRows = List.generate(rows, (_) => dataRow).join('\n');

    final table = '\n$header\n$separator\n$dataRows\n\n';

    controller.text =
        text.substring(0, selection.start) +
        table +
        text.substring(selection.end);
    controller.selection = TextSelection.collapsed(
      offset: selection.start + table.length,
    );
  }
}

/// Group of toolbar buttons
class _ToolbarButtonGroup extends StatelessWidget {
  final List<Widget> children;

  const _ToolbarButtonGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Individual toolbar button with hover effect
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool enabled; // 是否启用

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true, // 默认启用
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;

  void _handleTap() {
    if (!widget.enabled) return;
    // Provide haptic feedback on touch devices
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    final isTouchDevice =
        !isDesktop && MediaQuery.of(context).size.shortestSide < 600;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: isEnabled ? _handleTap : null,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            // Increase touch target size on touch devices (min 44px for accessibility)
            width: isTouchDevice ? 44 : (isDesktop ? 34 : 36),
            height: isTouchDevice ? 44 : (isDesktop ? 34 : 36),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              gradient: (_isHovered && isEnabled)
                  ? LinearGradient(
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              // Increase icon size slightly on touch devices
              size: isTouchDevice ? 20 : 18,
              color: isEnabled
                  ? (_isHovered
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7))
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3), // 禁用时灰色
            ),
          ),
        ),
      ),
    );
  }
}
