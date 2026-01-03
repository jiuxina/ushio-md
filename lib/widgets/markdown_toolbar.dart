import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Markdown editing toolbar with beautiful gradient buttons
class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;

  const MarkdownToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.format_bold,
                tooltip: '粗体',
                onPressed: () => _wrapSelection('**', '**'),
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                tooltip: '斜体',
                onPressed: () => _wrapSelection('*', '*'),
              ),
              _ToolbarButton(
                icon: Icons.format_strikethrough,
                tooltip: '删除线',
                onPressed: () => _wrapSelection('~~', '~~'),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.looks_one,
                tooltip: '标题 1',
                onPressed: () => _insertAtLineStart('# '),
              ),
              _ToolbarButton(
                icon: Icons.looks_two,
                tooltip: '标题 2',
                onPressed: () => _insertAtLineStart('## '),
              ),
              _ToolbarButton(
                icon: Icons.looks_3,
                tooltip: '标题 3',
                onPressed: () => _insertAtLineStart('### '),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.format_list_bulleted,
                tooltip: '无序列表',
                onPressed: () => _insertAtLineStart('- '),
              ),
              _ToolbarButton(
                icon: Icons.format_list_numbered,
                tooltip: '有序列表',
                onPressed: () => _insertAtLineStart('1. '),
              ),
              _ToolbarButton(
                icon: Icons.check_box_outlined,
                tooltip: '任务列表',
                onPressed: () => _insertAtLineStart('- [ ] '),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.format_quote,
                tooltip: '引用',
                onPressed: () => _insertAtLineStart('> '),
              ),
              _ToolbarButton(
                icon: Icons.code,
                tooltip: '行内代码',
                onPressed: () => _wrapSelection('`', '`'),
              ),
              _ToolbarButton(
                icon: Icons.data_object,
                tooltip: '代码块',
                onPressed: () => _insertCodeBlock(),
              ),
            ],
          ),
          _buildDivider(context),
          _ToolbarButtonGroup(
            children: [
              _ToolbarButton(
                icon: Icons.link,
                tooltip: '链接',
                onPressed: () => _insertLink(),
              ),
              _ToolbarButton(
                icon: Icons.image,
                tooltip: '图片',
                onPressed: () => _showImageDialog(context),
              ),
              _ToolbarButton(
                icon: Icons.horizontal_rule,
                tooltip: '分割线',
                onPressed: () => _insertText('\n---\n'),
              ),
              _ToolbarButton(
                icon: Icons.table_chart,
                tooltip: '表格',
                onPressed: () => _insertTable(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: Theme.of(context).dividerColor.withOpacity(0.3),
    );
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isCollapsed) {
      final newText = '$prefix文本$suffix';
      controller.text = text.substring(0, selection.start) +
          newText +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + 2,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = '$prefix$selectedText$suffix';
      controller.text = text.substring(0, selection.start) +
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

    controller.text = text.substring(0, lineStart) +
        prefix +
        text.substring(lineStart);
    controller.selection = TextSelection.collapsed(
      offset: selection.start + prefix.length,
    );
  }

  void _insertText(String textToInsert) {
    final text = controller.text;
    final selection = controller.selection;

    controller.text = text.substring(0, selection.start) +
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
      controller.text = text.substring(0, selection.start) +
          linkText +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + 1,
        extentOffset: selection.start + 5,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final linkText = '[$selectedText](https://example.com)';
      controller.text = text.substring(0, selection.start) +
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
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '插入图片',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildImageOption(
              context,
              icon: Icons.link,
              label: '输入图片链接',
              subtitle: '使用网络图片 URL',
              color: Colors.blue,
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
              color: Colors.green,
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
    required Color color,
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.link, color: Colors.blue),
            ),
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path ?? file.name;
        
        // Insert as local file path
        _insertImageWithUrl(path, file.name);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  void _insertImageWithUrl(String url, String description) {
    final text = controller.text;
    final selection = controller.selection;

    final imageText = '![$description]($url)';
    controller.text = text.substring(0, selection.start) +
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
      controller.text = text.substring(0, selection.start) +
          codeBlock +
          text.substring(selection.end);
      controller.selection = TextSelection(
        baseOffset: selection.start + 5,
        extentOffset: selection.start + 7,
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final codeBlock = '\n```\n$selectedText\n```\n';
      controller.text = text.substring(0, selection.start) +
          codeBlock +
          text.substring(selection.end);
      controller.selection = TextSelection.collapsed(
        offset: selection.start + codeBlock.length,
      );
    }
  }

  void _insertTable() {
    final text = controller.text;
    final selection = controller.selection;

    const table = '''

| 列1 | 列2 | 列3 |
|-----|-----|-----|
| 内容 | 内容 | 内容 |
| 内容 | 内容 | 内容 |

''';
    controller.text = text.substring(0, selection.start) +
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Individual toolbar button with hover effect
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              gradient: _isHovered
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _isHovered
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
