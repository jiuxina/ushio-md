import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/webview_markdown_preview.dart';
import '../widgets/particle_effect_widget.dart';
import '../models/toc_item.dart';
import 'editor/components/editor_header.dart';
import 'editor/components/toc_overlay.dart';
import 'editor/components/search_sheet.dart';
import 'editor/components/fullscreen_preview_page.dart';
import '../providers/plugin_provider.dart';
import '../plugins/extensions/shortcut_extension.dart';
import '../services/export_service.dart';

enum EditorMode { edit, preview, split }

/// Represents a logical block of markdown content for inline editing
class _MarkdownBlock {
  final int startLine;
  final int endLine;
  final String content;
  final bool isMultiLine;

  const _MarkdownBlock({
    required this.startLine,
    required this.endLine,
    required this.content,
    required this.isMultiLine,
  });
}

class EditorScreen extends StatefulWidget {
  final String filePath;

  const EditorScreen({super.key, required this.filePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with TickerProviderStateMixin {
  bool _isAutoCompleting = false;
  late TextEditingController _textController;
  late ScrollController _editScrollController;
  late UndoHistoryController _undoController;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  // WebView controller for heading navigation in preview/split modes
  final _previewWebViewController = MarkdownWebViewController();

  // Inline editing state (retained for reference; not activated from WebView preview)
  int? _editingBlockIndex;
  late TextEditingController _inlineEditController;
  late FocusNode _inlineEditFocusNode;

  EditorMode _mode = EditorMode.preview;
  bool _isLoading = true;
  bool _isModified = false;
  bool _isSaving = false;
  bool _showToc = false;
  bool _hidePlatformViews = false; // hide WebView during pop transition
  Timer? _autoSaveTimer;
  Timer? _tocDebounceTimer;
  int? _highlightedLine;

  // ==================== 常量 ====================
  /// Offset from top when jumping to a target position
  static const _jumpTopOffset = 32.0;

  // ==================== 正则表达式缓存 ====================
  static final _headingRegex = RegExp(r'^(#{1,6})\s*(.+)$');
  static final _h1UnderlineRegex = RegExp(r'^=+$');
  static final _h2UnderlineRegex = RegExp(r'^-+$');
  static final _uncheckedBoxRegex = RegExp(r'^(\s*-\s*)\[\s*\](.*)$');
  static final _checkedBoxRegex = RegExp(r'^(\s*-\s*)\[[xX]\](.*)$');
  static final _wordSplitRegex = RegExp(r'\s+');
  static final _codeBlockStartRegex = RegExp(r'^\s*```');
  static final _tableRowRegex = RegExp(r'^\s*\|');
  static final _blockquoteRegex = RegExp(r'^\s*>');

  String? _error;
  List<TocItem> _tocItems = [];

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editScrollController = ScrollController();
    _undoController = UndoHistoryController();
    _inlineEditController = TextEditingController();
    _inlineEditFocusNode = FocusNode();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fileService = context.read<FileProvider>().fileService;
      final content = await fileService.readFile(widget.filePath);
      if (!mounted) return;
      _textController.text = content;
      _textController.addListener(_onTextChanged);
      _updateToc();

      final settings = context.read<SettingsProvider>();
      if (settings.autoSave) {
        _autoSaveTimer = Timer.periodic(
          Duration(seconds: settings.autoSaveInterval),
          (_) => _autoSave(),
        );
      }
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onTextChanged() {
    if (!_isModified) {
      setState(() => _isModified = true);
    }
    _tocDebounceTimer?.cancel();
    _tocDebounceTimer = Timer(const Duration(milliseconds: 500), _updateToc);
    
    // 自动补全处理
    if (!_isAutoCompleting) {
      final text = _textController.text;
      final selection = _textController.selection;
      if (!selection.isValid || selection.start != selection.end) return;
      
      final pluginProvider = context.read<PluginProvider>();
      for (final ext in pluginProvider.getEditorExtensions()) {
        for (final rule in ext.autoCompleteRules) {
          if (rule.trigger.isEmpty) continue;
          
          if (selection.start >= rule.trigger.length) {
            final beforeCursor = text.substring(selection.start - rule.trigger.length, selection.start);
            if (beforeCursor == rule.trigger) {
              _isAutoCompleting = true;
              
              final newText = text.replaceRange(
                selection.start - rule.trigger.length, 
                selection.start, 
                rule.completion
              );
              
              final newSelectionOffset = selection.start - rule.trigger.length + rule.completion.length + rule.cursorOffset;
              
              _textController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newSelectionOffset),
              );
              
              _isAutoCompleting = false;
              return;
            }
          }
        }
      }
    }
  }

  /// 更新目录结构
  /// 
  /// 解析 Markdown 文本，提取标题（# 或 =/-）结构
  /// 仅在非代码块区域进行解析
  void _updateToc() {
    final text = _textController.text;
    final lines = text.split('\n');
    final items = <TocItem>[];
    int lineNumber = 0;
    bool inCodeBlock = false;

    // 预编译 pattern 避免循环中重复创建
    for (int i = 0; i < lines.length; i++) {
     final line = lines[i];
     final trimmedLine = line.trim();

     // 处理代码块标记
     if (trimmedLine.startsWith('```')) {
       inCodeBlock = !inCodeBlock;
       lineNumber++;
       continue;
     }

     if (inCodeBlock) {
       lineNumber++;
       continue;
     }

     // 1. 处理 # 标题
     if (trimmedLine.startsWith('#')) {
       final match = _headingRegex.firstMatch(trimmedLine);
       if (match != null) {
         final level = match.group(1)!.length;
         final title = match.group(2)!.trim();
         items.add(TocItem(
           level: level,
           title: title,
           lineNumber: lineNumber,
           anchorKey: GlobalKey(), // Create GlobalKey for anchor point
         ));
       }
     }
     // 2. 处理下划线标题 (= 和 -)
     else if (trimmedLine.isNotEmpty && i + 1 < lines.length) {
       final nextLine = lines[i + 1].trim();
       if (nextLine.isNotEmpty) {
         if (_h1UnderlineRegex.hasMatch(nextLine)) {
           items.add(TocItem(
             level: 1,
             title: trimmedLine,
             lineNumber: lineNumber,
             anchorKey: GlobalKey(), // Create GlobalKey for anchor point
           ));
         } else if (_h2UnderlineRegex.hasMatch(nextLine)) {
           items.add(TocItem(
             level: 2,
             title: trimmedLine,
             lineNumber: lineNumber,
             anchorKey: GlobalKey(), // Create GlobalKey for anchor point
           ));
         }
       }
     }
     lineNumber++;
    }

    setState(() => _tocItems = items);
  }

  void _jumpToHeading(TocItem item) {
    setState(() {
      _showToc = false;
    });

    if (_mode == EditorMode.edit) {
      // Scroll the text editor to the target line
      setState(() => _highlightedLine = item.lineNumber);
      final lines = _textController.text.split('\n');
      int position = 0;
      for (int i = 0; i < item.lineNumber && i < lines.length; i++) {
        position += lines[i].length + 1;
      }
      _textController.selection = TextSelection.collapsed(offset: position);
      if (_editScrollController.hasClients) {
        const lineHeight = 24.0;
        final maxScroll = _editScrollController.position.maxScrollExtent;
        final targetScroll =
            (item.lineNumber * lineHeight - _jumpTopOffset).clamp(0.0, maxScroll);
        _editScrollController.jumpTo(targetScroll);
      }
      // Trigger Flutter-side highlight flash for edit mode
      _highlightController.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _highlightedLine = null);
        });
      });
    } else {
      // WebView preview/split mode — scroll via JavaScript.
      // The JS also handles the visual flash on the target heading.
      final headingIndex = _tocItems.indexOf(item);
      if (headingIndex >= 0) {
        _previewWebViewController.scrollToHeading(headingIndex,
            topOffset: _jumpTopOffset);
      }
    }
  }

  /// 自动保存
  ///
  /// 仅在内容有修改且未在保存中时触发
  Future<void> _autoSave() async {
    if (_isModified && !_isSaving) {
      await _saveFile(showSnackbar: false);
    }
  }

  /// 保存文件
  ///
  /// [showSnackbar] 是否显示保存结果提示
  Future<void> _saveFile({bool showSnackbar = true}) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final fileService = context.read<FileProvider>().fileService;
      await fileService.saveFile(widget.filePath, _textController.text);
      if (mounted) setState(() => _isModified = false);

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('已保存'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('保存失败: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _tocDebounceTimer?.cancel();
    _textController.dispose();
    _editScrollController.dispose();
    _undoController.dispose();
    _inlineEditFocusNode.removeListener(_onInlineEditFocusChanged);
    _inlineEditController.dispose();
    _inlineEditFocusNode.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // Finish any inline edit first
    if (_editingBlockIndex != null) {
      _finishInlineEdit();
    }

    if (!_isModified) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text('未保存的更改'),
          ],
        ),
        content: const Text('您有未保存的更改，要保存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'save'),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveFile();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchSheet(
        text: _textController.text,
        onMatchSelected: (position, length) {
          Navigator.pop(context);

          if (_mode == EditorMode.edit) {
            // Edit mode: select text and scroll the editor
            Future.delayed(const Duration(milliseconds: 100), () {
              _textController.selection = TextSelection(
                baseOffset: position,
                extentOffset: position + length,
              );

              if (_editScrollController.hasClients) {
                final lines =
                    _textController.text.substring(0, position).split('\n');
                const lineHeight = 24.0;
                final targetScroll =
                    (lines.length * lineHeight - _jumpTopOffset);
                _editScrollController.jumpTo(
                  targetScroll
                      .clamp(0.0, _editScrollController.position.maxScrollExtent),
                );
              }
            });
          } else {
            // Preview / split mode: scroll the WebView to the matched text
            final end = (position + length).clamp(0, _textController.text.length);
            final matchText = _textController.text.substring(position, end);
            _previewWebViewController.scrollToText(matchText);
          }
        },
      ),
    );
  }

  void _openFullscreenPreview() {
    final settings = context.read<SettingsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenPreviewPage(
          controller: _textController,
          settings: settings,
          fileName: fileName,
          onCheckboxChanged: _toggleCheckbox,
        ),
      ),
    );
  }

  /// 切换复选框状态
  ///
  /// The WebView's HTML checkbox state is already correct immediately on user
  /// tap, so we suppress the next content reload and just update the underlying
  /// text for persistence.
  void _toggleCheckbox(int index, bool newValue) {
    final text = _textController.text;
    final lines = text.split('\n');
    int checkboxCount = 0;
    bool changed = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final uncheckedMatch = _uncheckedBoxRegex.firstMatch(line);
      final checkedMatch = _checkedBoxRegex.firstMatch(line);

      if (uncheckedMatch != null || checkedMatch != null) {
        if (checkboxCount == index) {
          if (newValue && uncheckedMatch != null) {
            lines[i] = '${uncheckedMatch.group(1)}[x]${uncheckedMatch.group(2)}';
            changed = true;
          } else if (!newValue && checkedMatch != null) {
            lines[i] = '${checkedMatch.group(1)}[ ]${checkedMatch.group(2)}';
            changed = true;
          }
          break;
        }
        checkboxCount++;
      }
    }

    if (changed) {
      // Suppress the next WebView reload – the HTML checkbox is already correct.
      _previewWebViewController.suppressNextReload();
      final newText = lines.join('\n');
      _textController.removeListener(_onTextChanged);
      _textController.text = newText;
      _textController.addListener(_onTextChanged);
      setState(() => _isModified = true);
    }
  }

  /// Handle link tap in preview
  ///
  /// Opens external URLs in browser, navigates to local markdown files
  void _handleLinkTap(String text, String? href, String title) {
    if (href == null || href.isEmpty) return;

    // Handle local markdown file links
    if (href.endsWith('.md') || href.endsWith('.markdown')) {
      // Sanitize: reject path traversal attempts
      if (!href.contains('..')) {
        final baseDir = File(widget.filePath).parent.path;
        final targetPath = '$baseDir${Platform.pathSeparator}${href.replaceAll('/', Platform.pathSeparator)}';
        final targetFile = File(targetPath);
        if (targetFile.existsSync()) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditorScreen(filePath: targetPath),
            ),
          );
          return;
        }
      }
    }

    // Open external URLs in browser
    final uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Ignore launch failures
      }
    }
  }

  // ==================== Block Parsing & Inline Editing ====================

  // ── In-place editing helpers ──────────────────────────────────────────

  /// Strip markdown formatting from text so it can be compared to HTML
  /// innerText returned by the WebView.
  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), r'$1')
        .replaceAll(RegExp(r'_{1,3}([^_]+)_{1,3}'), r'$1')
        .replaceAll(RegExp(r'`+([^`]+)`+'), r'$1')
        .replaceAll(RegExp(r'~~([^~]+)~~'), r'$1')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), '')
        .replaceAll(RegExp(r'\[([^\]]*)\]\([^\)]*\)'), r'$1')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '')
        .trim()
        .toLowerCase();
  }

  /// Returns the raw markdown source for a table cell (for in-place editing).
  String _getCellMarkdown(int tableIdx, int rowIdx, int colIdx) {
    final blocks = _parseBlocks(_textController.text);
    final tableBlocks =
        blocks.where((b) => b.isMultiLine && b.content.contains('|')).toList();
    if (tableIdx >= tableBlocks.length) return '';
    // Skip separator rows (lines that consist only of |, -, :, and spaces)
    final _sepRow = RegExp(r'^[\|\s\-:]+$');
    final tableLines = tableBlocks[tableIdx]
        .content
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !_sepRow.hasMatch(l.trim()))
        .toList();
    if (rowIdx >= tableLines.length) return '';
    final parts = tableLines[rowIdx].split('|');
    final idx = colIdx + 1;
    if (idx >= parts.length) return '';
    return parts[idx].trim();
  }

  /// Returns the raw markdown source for the block whose rendered innerText
  /// best matches [innerText].
  String _getBlockMarkdown(String innerText) {
    final blocks = _parseBlocks(_textController.text);
    final normalizedHtml = _stripMarkdown(innerText);
    int bestIndex = -1;
    int bestLen = 0;
    for (int i = 0; i < blocks.length; i++) {
      final norm = _stripMarkdown(blocks[i].content);
      if (norm.isEmpty) continue;
      final shorter =
          norm.length <= normalizedHtml.length ? norm : normalizedHtml;
      final longer =
          norm.length > normalizedHtml.length ? norm : normalizedHtml;
      if (longer.contains(shorter) && shorter.length > bestLen) {
        bestLen = shorter.length;
        bestIndex = i;
      }
    }
    return bestIndex >= 0 ? blocks[bestIndex].content : innerText;
  }

  /// Callback for `onGetMarkdown` from [WebViewMarkdownPreview].
  String _handleGetMarkdown(
      String type, int p1, int p2, int p3, String extra) {
    if (type == 'cell') return _getCellMarkdown(p1, p2, p3);
    return _getBlockMarkdown(extra);
  }

  /// Apply an in-place edit committed by the WebView contenteditable.
  ///
  /// [key] is either `'cell:ti:ri:ci'` or `'block:<innerText prefix>'`.
  /// [newText] is the raw markdown the user typed.
  void _applyInPlaceEdit(String key, String newText) {
    if (!mounted) return;
    if (key.startsWith('cell:')) {
      final parts = key.split(':');
      if (parts.length < 4) return;
      final ti = int.tryParse(parts[1]) ?? 0;
      final ri = int.tryParse(parts[2]) ?? 0;
      final ci = int.tryParse(parts[3]) ?? 0;
      final blocks = _parseBlocks(_textController.text);
      final tableBlocks = blocks
          .where((b) => b.isMultiLine && b.content.contains('|'))
          .toList();
      if (ti >= tableBlocks.length) return;
      _inlineEditController.text = newText;
      _applyCellEdit(tableBlocks[ti], ri, ci);
    } else if (key.startsWith('block:')) {
      // key = 'block:' + first 80 chars of innerText → fuzzy-find block
      final innerText = key.substring('block:'.length);
      final blocks = _parseBlocks(_textController.text);
      final normalized = _stripMarkdown(innerText);
      int bestIndex = -1;
      int bestLen = 0;
      for (int i = 0; i < blocks.length; i++) {
        final norm = _stripMarkdown(blocks[i].content);
        if (norm.isEmpty) continue;
        final shorter =
            norm.length <= normalized.length ? norm : normalized;
        final longer =
            norm.length > normalized.length ? norm : normalized;
        if (longer.contains(shorter) && shorter.length > bestLen) {
          bestLen = shorter.length;
          bestIndex = i;
        }
      }
      if (bestIndex >= 0) {
        _inlineEditController.text = newText;
        _applyBlockEdit(bestIndex, blocks);
      }
    }
  }

  /// Apply an edited cell back into the markdown text.
  void _applyCellEdit(_MarkdownBlock tableBlock, int rowIdx, int colIdx) {
    final allLines = _textController.text.split('\n');
    // Skip separator rows (lines that consist only of |, -, :, and spaces)
    final _sepRow = RegExp(r'^[\|\s\-:]+$');
    int tableRowCounter = 0;
    for (int i = tableBlock.startLine;
        i <= tableBlock.endLine && i < allLines.length;
        i++) {
      final trimmed = allLines[i].trim();
      if (trimmed.isEmpty) continue;
      if (_sepRow.hasMatch(trimmed)) continue; // skip separator
      if (tableRowCounter == rowIdx) {
        final parts = allLines[i].split('|');
        final cellPartIdx = colIdx + 1;
        if (cellPartIdx < parts.length) {
          parts[cellPartIdx] = ' ${_inlineEditController.text} ';
          allLines[i] = parts.join('|');
        }
        break;
      }
      tableRowCounter++;
    }
    final newText = allLines.join('\n');
    if (newText != _textController.text) {
      setState(() {
        _textController.text = newText;
        _isModified = true;
      });
    }
  }

  /// Apply the block editor result back into the full document.
  void _applyBlockEdit(int blockIndex, List<_MarkdownBlock> blocks) {
    if (blockIndex >= blocks.length) return;
    final block = blocks[blockIndex];
    final lines = _textController.text.split('\n');
    final editedLines = _inlineEditController.text.split('\n');
    final newLines = <String>[
      ...lines.sublist(0, block.startLine),
      ...editedLines,
      if (block.endLine + 1 < lines.length) ...lines.sublist(block.endLine + 1),
    ];
    final newText = newLines.join('\n');
    if (newText != _textController.text) {
      setState(() {
        _textController.text = newText;
        _isModified = true;
      });
    }
  }

  /// Parse markdown text into logical blocks for inline editing.
  /// Code blocks, tables, and blockquotes are grouped as multi-line blocks.
  /// All other lines are individual blocks.
  List<_MarkdownBlock> _parseBlocks(String text) {
    final lines = text.split('\n');
    final blocks = <_MarkdownBlock>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code block: ``` to ```
      if (_codeBlockStartRegex.hasMatch(trimmed)) {
        int end = i + 1;
        while (end < lines.length && !_codeBlockStartRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        if (end < lines.length) end++; // include closing ```
        blocks.add(_MarkdownBlock(
          startLine: i,
          endLine: end - 1,
          content: lines.sublist(i, end).join('\n'),
          isMultiLine: true,
        ));
        i = end;
        continue;
      }

      // Table: contiguous | lines (need at least 2 rows)
      if (_tableRowRegex.hasMatch(trimmed) && i + 1 < lines.length && _tableRowRegex.hasMatch(lines[i + 1].trim())) {
        int end = i;
        while (end < lines.length && _tableRowRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        blocks.add(_MarkdownBlock(
          startLine: i,
          endLine: end - 1,
          content: lines.sublist(i, end).join('\n'),
          isMultiLine: true,
        ));
        i = end;
        continue;
      }

      // Blockquote: contiguous > lines
      if (_blockquoteRegex.hasMatch(trimmed)) {
        int end = i;
        while (end < lines.length && _blockquoteRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        blocks.add(_MarkdownBlock(
          startLine: i,
          endLine: end - 1,
          content: lines.sublist(i, end).join('\n'),
          isMultiLine: end > i + 1,
        ));
        i = end;
        continue;
      }

      // Single line
      blocks.add(_MarkdownBlock(
        startLine: i,
        endLine: i,
        content: line,
        isMultiLine: false,
      ));
      i++;
    }

    return blocks;
  }

  /// Count checkboxes in a text segment
  int _countCheckboxesInText(String text) {
    int count = 0;
    for (final line in text.split('\n')) {
      if (_uncheckedBoxRegex.hasMatch(line) || _checkedBoxRegex.hasMatch(line)) {
        count++;
      }
    }
    return count;
  }

  /// Start inline editing for a specific block
  void _startInlineEdit(int blockIndex, List<_MarkdownBlock> blocks) {
    if (blockIndex < 0 || blockIndex >= blocks.length) return;

    // Finish any current editing first
    if (_editingBlockIndex != null) {
      _finishInlineEdit();
    }

    // Re-parse blocks after finishing previous edit
    final currentBlocks = _parseBlocks(_textController.text);
    if (blockIndex >= currentBlocks.length) return;

    _inlineEditController.text = currentBlocks[blockIndex].content;
    setState(() {
      _editingBlockIndex = blockIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inlineEditFocusNode.requestFocus();
    });
  }

  /// Finish inline editing and apply changes
  void _finishInlineEdit() {
    if (_editingBlockIndex == null) return;

    final blocks = _parseBlocks(_textController.text);
    final editingIndex = _editingBlockIndex!;

    // Clear editing state first
    setState(() => _editingBlockIndex = null);

    if (editingIndex < blocks.length) {
      final block = blocks[editingIndex];
      final lines = _textController.text.split('\n');

      final editedLines = _inlineEditController.text.split('\n');
      final newLines = <String>[
        ...lines.sublist(0, block.startLine),
        ...editedLines,
        if (block.endLine + 1 < lines.length)
          ...lines.sublist(block.endLine + 1),
      ];

      final newText = newLines.join('\n');
      if (newText != _textController.text) {
        _textController.text = newText;
        // _isModified will be set by _onTextChanged listener
      }
    }
  }

  /// Cancel inline editing without saving
  void _cancelInlineEdit() {
    setState(() => _editingBlockIndex = null);
  }

  /// Return the background and foreground colors for the active theme scheme.
  ({Color bg, Color fg}) _themeSchemeColors(SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      final schemes = AppConstants.darkThemeSchemes;
      final idx = settings.darkThemeIndex.clamp(0, schemes.length - 1);
      final s = schemes[idx];
      return (bg: s.background, fg: s.text);
    } else {
      final schemes = AppConstants.lightThemeSchemes;
      final idx = settings.lightThemeIndex.clamp(0, schemes.length - 1);
      final s = schemes[idx];
      return (bg: s.background, fg: s.text);
    }
  }

  /// Build the WebView-based preview for EditorMode.preview.
  Widget _buildInlineEditablePreview(SettingsProvider settings) {
    if (_hidePlatformViews) return const SizedBox.expand();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _themeSchemeColors(settings);
    return WebViewMarkdownPreview(
      data: _textController.text,
      isDark: isDark,
      fontSize: settings.fontSize,
      fontFamily:
          settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
      bgColor: colors.bg,
      fgColor: colors.fg,
      codeFont: settings.codeFontFamily == 'System' ? null : settings.codeFontFamily,
      baseDirectory: File(widget.filePath).parent.path,
      onTapLink: _handleLinkTap,
      onCheckboxChanged: _toggleCheckbox,
      onGetMarkdown: _handleGetMarkdown,
      onInPlaceEdit: _applyInPlaceEdit,
      controller: _previewWebViewController,
    );
  }

  /// Build the inline editor widget for a block.
  ///
  /// No confirm/cancel buttons – tapping outside the field (focus-lost) saves
  /// the change; pressing Enter on a single-line block also saves.
  Widget _buildBlockEditor(_MarkdownBlock block, SettingsProvider settings) {
    // Auto-save when the field loses focus (user tapped elsewhere)
    _inlineEditFocusNode.removeListener(_onInlineEditFocusChanged);
    _inlineEditFocusNode.addListener(_onInlineEditFocusChanged);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: TextField(
        controller: _inlineEditController,
        focusNode: _inlineEditFocusNode,
        maxLines: block.isMultiLine ? null : 1,
        keyboardType: block.isMultiLine ? TextInputType.multiline : TextInputType.text,
        onSubmitted: block.isMultiLine ? null : (_) => _finishInlineEdit(),
        style: TextStyle(
          fontSize: settings.fontSize,
          fontFamily: settings.editorFontFamily == 'System'
              ? (block.content.trimLeft().startsWith('```') ? 'monospace' : null)
              : settings.editorFontFamily,
          height: 1.5,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
          hintText: block.isMultiLine ? '编辑此块...' : '编辑此行...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// Save inline edit when the text field loses focus (user tapped outside).
  void _onInlineEditFocusChanged() {
    if (!_inlineEditFocusNode.hasFocus && _editingBlockIndex != null) {
      _finishInlineEdit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isModified,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Clear the WebView platform surface immediately so the native view
          // doesn't linger as a ghost during the route-pop animation.
          if (mounted) setState(() => _hidePlatformViews = true);
          return;
        }
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            setState(() => _hidePlatformViews = true);
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: CallbackShortcuts(
          bindings: _buildShortcutBindings(),
          child: Stack(
            children: [
              _buildBody(),
              if (_showToc)
                TocOverlay(
                  items: _tocItems,
                  onClose: () => setState(() => _showToc = false),
                  onJumpToHeading: _jumpToHeading,
                ),
              // Floating buttons – positioned relative to the full screen so
              // they stay fixed even when the keyboard is shown.
              if (!_isLoading && _error == null)
                _buildFixedFloatingButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
              : [const Color(0xFFf8f9ff), const Color(0xFFf0f4ff)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                EditorHeader(
                  fileName: fileName,
                  wordCount: _getWordCount(),
                  isModified: _isModified,
                  isSaving: _isSaving,
                  onBack: () async {
                    if (_isModified) {
                      final shouldPop = await _onWillPop();
                      if (shouldPop && mounted) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  onSave: _saveFile,
                  onMore: _showMoreMenu,
                ),
                Expanded(child: _buildContent()),
                // Toolbar at bottom (above keyboard when shown)
                if (!_isLoading && _error == null && (_mode != EditorMode.preview || _editingBlockIndex != null))
                  MarkdownToolbar(
                    controller: _editingBlockIndex != null ? _inlineEditController : _textController,
                    undoController: _editingBlockIndex != null ? null : _undoController,
                    filePath: widget.filePath,
                    onSearchPressed: _showSearchDialog,
                  ),
              ],
            ),
          ),
          // 粒子效果层（全局模式时显示）
          if (settings.particleEnabled && settings.particleGlobal)
            Positioned.fill(
              child: IgnorePointer(
                child: ParticleEffectWidget(
                  particleType: settings.particleType,
                  speed: settings.particleSpeed,
                  enabled: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getWordCount() {
    final text = _textController.text;
    final chars = text.length;
    final words = text.split(_wordSplitRegex).where((w) => w.isNotEmpty).length;
    return '$chars 字符 · $words 词';
  }


  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '正在加载...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadFile,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildEditor();
  }

  Widget _buildEditor() {
    final settings = context.watch<SettingsProvider>();

    switch (_mode) {
      case EditorMode.edit:
        // Edge-to-edge: no left/right/bottom margin or border.
        return Container(
          margin: const EdgeInsets.only(top: 8),
          color: Theme.of(context).colorScheme.surface,
          child: _buildEditPanel(settings),
        );
      case EditorMode.preview:
        // Edge-to-edge: no left/right/bottom margin or border.
        return Container(
          margin: const EdgeInsets.only(top: 8),
          color: Theme.of(context).colorScheme.surface,
          child: _buildInlineEditablePreview(settings),
        );
      case EditorMode.split:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildEditPanel(settings),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPreviewPanel(settings),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Floating action buttons that stay fixed at the bottom-right corner of the
  /// screen, unaffected by the keyboard (they are positioned in the top-level
  /// Stack, not inside the Scaffold body that resizes for the IME).
  Widget _buildFixedFloatingButtons() {
    // Bottom offset: respect the device's safe-area (status-bar / nav-bar) but
    // ignore the keyboard inset, so the buttons don't jump when the IME appears.
    final bottomInset = MediaQuery.of(context).padding.bottom + 24.0;

    switch (_mode) {
      case EditorMode.edit:
        return Positioned(
          right: 24,
          bottom: bottomInset,
          child: _buildFloatingButton(
            Icons.visibility,
            Theme.of(context).colorScheme.primary,
            () => setState(() => _mode = EditorMode.preview),
          ),
        );
      case EditorMode.preview:
        if (_editingBlockIndex != null) return const SizedBox.shrink();
        return Positioned(
          right: 24,
          bottom: bottomInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingButton(
                Icons.edit,
                Theme.of(context).colorScheme.tertiary,
                () => setState(() => _mode = EditorMode.edit),
              ),
              const SizedBox(height: 12),
              _buildFloatingButton(
                Icons.list,
                Theme.of(context).colorScheme.primary,
                () => setState(() => _showToc = true),
              ),
            ],
          ),
        );
      case EditorMode.split:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFloatingButton(IconData icon, Color color, VoidCallback onTap, {bool mini = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mini ? 12 : 16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(mini ? 10 : 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(mini ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: mini ? 18 : 24,
          ),
        ),
      ),
    );
  }

  Widget _buildEditPanel(SettingsProvider settings) {
    return Stack(
      children: [
        TextField(
          controller: _textController,
          scrollController: _editScrollController,
          undoController: _undoController,
          maxLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontSize: settings.fontSize,
            fontFamily: settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
            height: 1.5,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
            hintText: '开始编写你的 Markdown 内容...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (_highlightedLine != null && _mode == EditorMode.edit)
          AnimatedBuilder(
            animation: _highlightAnimation,
            builder: (context, child) {
              final accentColor = Theme.of(context).colorScheme.primary;
              const lineHeight = 24.0;
              final topPosition = _highlightedLine! * lineHeight;

              // Single flash: fade in then fade out
              final opacity = _highlightAnimation.value < 0.5
                  ? _highlightAnimation.value * 2
                  : (1 - _highlightAnimation.value) * 2;

              return Positioned(
                top: topPosition,
                left: 0,
                right: 0,
                height: lineHeight,
                child: IgnorePointer(
                  child: Container(
                    color: accentColor.withValues(alpha: opacity * 0.35),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Build the WebView-based preview panel for EditorMode.split.
  Widget _buildPreviewPanel(SettingsProvider settings) {
    if (_hidePlatformViews) return const SizedBox.expand();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _themeSchemeColors(settings);
    return WebViewMarkdownPreview(
      data: _textController.text,
      isDark: isDark,
      fontSize: settings.fontSize,
      fontFamily:
          settings.editorFontFamily == 'System' ? null : settings.editorFontFamily,
      bgColor: colors.bg,
      fgColor: colors.fg,
      codeFont: settings.codeFontFamily == 'System' ? null : settings.codeFontFamily,
      baseDirectory: File(widget.filePath).parent.path,
      onTapLink: _handleLinkTap,
      onCheckboxChanged: _toggleCheckbox,
      onGetMarkdown: _handleGetMarkdown,
      onInPlaceEdit: _applyInPlaceEdit,
      controller: _previewWebViewController,
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings() {
    final bindings = <ShortcutActivator, VoidCallback>{};
    final pluginProvider = context.read<PluginProvider>();
    
    for (final ext in pluginProvider.getShortcutExtensions()) {
      if (ext.logicalKeys.isEmpty) continue;
      
      final triggerKey = ext.logicalKeys.last;
      final hasControl = ext.logicalKeys.contains(LogicalKeyboardKey.control) || 
                        ext.logicalKeys.contains(LogicalKeyboardKey.meta);
      final hasShift = ext.logicalKeys.contains(LogicalKeyboardKey.shift);
      final hasAlt = ext.logicalKeys.contains(LogicalKeyboardKey.alt);

      final activator = SingleActivator(
        triggerKey,
        control: hasControl,
        shift: hasShift,
        alt: hasAlt,
      );

      bindings[activator] = () {
        _handlePluginShortcut(ext);
      };
    }

    return bindings;
  }

  void _handlePluginShortcut(PluginShortcutExtension ext) {
    debugPrint('Triggered shortcut: ${ext.shortcutId}');
    switch (ext.actionType) {
      case ShortcutActionType.insertText:
        final text = ext.actionParams['text'] as String?;
        if (text != null) {
          final selection = _textController.selection;
          final newText = _textController.text.replaceRange(
            selection.start, selection.end, text
          );
          _textController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start + text.length),
          );
          _onTextChanged();
        }
        break;
      case ShortcutActionType.toggleMode:
         final modeStr = ext.actionParams['mode'] as String?;
         if (modeStr == 'preview') {
           setState(() => _mode = _mode == EditorMode.preview ? EditorMode.edit : EditorMode.preview);
         } else if (modeStr == 'split') {
            setState(() => _mode = _mode == EditorMode.split ? EditorMode.edit : EditorMode.split);
         }
         break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('插件快捷键: ${ext.description} (未实现)')),
        );
    }
  }

  void _showMoreMenu() {
    final pluginProvider = context.read<PluginProvider>();
    
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索'),
              onTap: () {
                Navigator.pop(context);
                _showSearchDialog();
              },
            ),
             ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('全屏预览'),
              onTap: () {
                Navigator.pop(context);
                _openFullscreenPreview();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('导出为 PDF'),
              onTap: () async {
                Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('正在生成 PDF...')),
                );
                await ExportService.exportAndShareAsPdf(
                  _textController.text,
                  widget.filePath.split(Platform.pathSeparator).last.replaceAll('.md', ''),
                );
              },
            ),
            ...pluginProvider.getExportExtensions().map((ext) {
               return ListTile(
                leading: const Icon(Icons.extension),
                title: Text('导出为 ${ext.formatName}'),
                subtitle: Text(ext.formatId),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('插件导出: ${ext.formatName} (待实现)')),
                  );
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
