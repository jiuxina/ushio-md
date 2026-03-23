import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/editor_navigation_helper.dart';
import '../utils/app_style.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/milkdown_webview_editor.dart';
import '../widgets/particle_effect_widget.dart';
import '../models/toc_item.dart';
import '../models/milkdown_bridge.dart';
import 'editor/components/editor_header.dart';
import 'editor/components/toc_overlay.dart';
import 'editor/components/fullscreen_preview_page.dart';
import '../services/export_service.dart';

enum EditorMode { edit, preview }

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


class _EditHistoryEntry {
  final String text;
  final TextSelection selection;

  const _EditHistoryEntry({required this.text, required this.selection});
}

class _SearchMatch {
  final int position;
  final int length;
  final String preview;
  final int occurrence;

  const _SearchMatch({
    required this.position,
    required this.length,
    required this.preview,
    required this.occurrence,
  });
}

class EditorScreen extends StatefulWidget {
  final String filePath;
  final String? initialContent;

  const EditorScreen({
    super.key,
    required this.filePath,
    this.initialContent,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  bool _isAutoCompleting = false;
  static const int _maxEditHistory = 100;
  final List<_EditHistoryEntry> _editHistory = <_EditHistoryEntry>[];
  int _historyIndex = -1;
  bool _isApplyingHistory = false;
  bool _textListenerAttached = false;

  late TextEditingController _textController;
  late TextEditingController _searchController;
  late ScrollController _editScrollController;
  late UndoHistoryController _undoController;
  late FocusNode _searchFocusNode;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  // WebView controller for heading navigation in the rendered preview page
  final _previewWebViewController = MilkdownWebViewController();

  // Inline editing state (retained for reference; not activated from WebView preview)
  int? _editingBlockIndex;
  late TextEditingController _inlineEditController;
  late FocusNode _inlineEditFocusNode;

  EditorMode _mode = EditorMode.preview;
  bool _isLoading = true;
  bool _isModified = false;
  bool _isSaving = false;
  bool _showToc = false;
  bool _showSearchBar = false;
  bool _showSearchCandidates = false;
  final TocOverlayController _tocOverlayController = TocOverlayController();
  bool _hidePlatformViews = false; // hide WebView during pop transition
  Timer? _autoSaveTimer;
  int? _highlightedLine;
  List<_SearchMatch> _searchMatches = const [];
  int _activeSearchMatchIndex = -1;

  // ==================== 常量 ====================
  /// Offset from top when jumping to a target position
  static const _jumpTopOffset = 32.0;

  // ==================== 正则表达式缓存 ====================
  static final _uncheckedBoxRegex = RegExp(r'^(\s*-\s*)\[\s*\](.*)$');
  static final _checkedBoxRegex = RegExp(r'^(\s*-\s*)\[[xX]\](.*)$');
  static final _wordSplitRegex = RegExp(r'\s+');
  static final _codeBlockStartRegex = RegExp(r'^\s*```');
  static final _tableRowRegex = RegExp(r'^\s*\|');
  static final _blockquoteRegex = RegExp(r'^\s*>');
  static final _listItemStartRegex = RegExp(r'^\s*(?:[-*+]|\d+\.)\s+');
  static final _indentedContentRegex = RegExp(r'^\s{2,}\S');
  static final _nestedListMarkerRegex = RegExp(r'^\s{2,}(?:[-*+]|\d+\.)\s+');

  String? _error;
  List<TocItem> _tocItems = [];

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _searchController = TextEditingController();
    _editScrollController = ScrollController();
    _undoController = UndoHistoryController();
    _searchFocusNode = FocusNode();
    _inlineEditController = TextEditingController();
    _inlineEditFocusNode = FocusNode();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );
    _searchFocusNode.addListener(_onSearchFocusChanged);
    if (widget.initialContent != null) {
      _applyLoadedContent(widget.initialContent!);
      _configureAutoSave();
      _isLoading = false;
    } else {
      _loadFile();
    }
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
      _applyLoadedContent(content);
      _configureAutoSave();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyLoadedContent(String content) {
    _textController.text = content;
    if (!_textListenerAttached) {
      _textController.addListener(_onTextChanged);
      _textListenerAttached = true;
    }
    _recordHistorySnapshot(
      text: content,
      selection: const TextSelection.collapsed(offset: 0),
      reset: true,
    );
  }

  void _configureAutoSave() {
    _autoSaveTimer?.cancel();
    final settings = context.read<SettingsProvider>();
    if (settings.autoSave) {
      _autoSaveTimer = Timer.periodic(
        Duration(seconds: settings.autoSaveInterval),
        (_) => _autoSave(),
      );
    }
  }

  void _onTextChanged() {
    if (!_isModified) {
      setState(() => _isModified = true);
    }

    if (!_isApplyingHistory) {
      _recordHistorySnapshot();
    }

  }

  void _recordHistorySnapshot({
    String? text,
    TextSelection? selection,
    bool reset = false,
  }) {
    final t = text ?? _textController.text;
    final s = selection ?? _textController.selection;
    final safe = _safeSelection(s, t.length);

    if (reset) {
      _editHistory
        ..clear()
        ..add(_EditHistoryEntry(text: t, selection: safe));
      _historyIndex = 0;
      return;
    }

    if (_historyIndex >= 0 && _historyIndex < _editHistory.length) {
      final cur = _editHistory[_historyIndex];
      if (cur.text == t) return;
    }

    if (_historyIndex < _editHistory.length - 1) {
      _editHistory.removeRange(_historyIndex + 1, _editHistory.length);
    }

    _editHistory.add(_EditHistoryEntry(text: t, selection: safe));
    if (_editHistory.length > _maxEditHistory) {
      final overflow = _editHistory.length - _maxEditHistory;
      _editHistory.removeRange(0, overflow);
      _historyIndex = (_historyIndex - overflow).clamp(0, _editHistory.length - 1);
    }
    _historyIndex = _editHistory.length - 1;
    if (mounted) setState(() {});
  }

  TextSelection _safeSelection(TextSelection sel, int textLength) {
    final base = sel.baseOffset.clamp(0, textLength).toInt();
    final extent = sel.extentOffset.clamp(0, textLength).toInt();
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  void _applyMainTextWithSelection(String newText, TextSelection selection) {
    _isApplyingHistory = true;
    _textController.value = TextEditingValue(
      text: newText,
      selection: _safeSelection(selection, newText.length),
    );
    _isApplyingHistory = false;
    _recordHistorySnapshot(text: newText, selection: selection);
  }

  void _undoEditHistory() {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    final entry = _editHistory[_historyIndex];
    _isApplyingHistory = true;
    _textController.value = TextEditingValue(text: entry.text, selection: entry.selection);
    _isApplyingHistory = false;
    setState(() {});
  }

  void _redoEditHistory() {
    if (_historyIndex < 0 || _historyIndex >= _editHistory.length - 1) return;
    _historyIndex++;
    final entry = _editHistory[_historyIndex];
    _isApplyingHistory = true;
    _textController.value = TextEditingValue(text: entry.text, selection: entry.selection);
    _isApplyingHistory = false;
    setState(() {});
  }

  void _handleOutlineUpdate(OnOutlineUpdatePayload payload) {
    final items = payload.outline
        .map((node) {
          final lineNumber = int.tryParse(node.id.replaceFirst('line-', '')) ?? 0;
          return TocItem(
            level: node.level,
            title: node.text,
            lineNumber: lineNumber,
            anchorKey: GlobalKey(),
          );
        })
        .toList(growable: false);
    if (!mounted) return;
    setState(() => _tocItems = items);
  }

  void _jumpToHeading(TocItem item) {
    if (_showToc) {
      _tocOverlayController.close();
    }

    if (_mode == EditorMode.edit) {
      // Scroll the text editor to the target line
      final lines = _textController.text.split('\n');
      int position = 0;
      for (int i = 0; i < item.lineNumber && i < lines.length; i++) {
        position += lines[i].length + 1;
      }
      _textController.selection = TextSelection.collapsed(offset: position);
      if (_editScrollController.hasClients) {
        const lineHeight = 24.0;
        final maxScroll = _editScrollController.position.maxScrollExtent;
        final targetScroll = (item.lineNumber * lineHeight - _jumpTopOffset)
            .clamp(0.0, maxScroll);
        _editScrollController.jumpTo(targetScroll);
      }
      _flashLineHighlight(item.lineNumber);
    } else {
      // Rendered preview page — scroll via JavaScript.
      // The JS also handles the visual flash on the target heading.
      final headingIndex = _tocItems.indexOf(item);
      if (headingIndex >= 0) {
        _previewWebViewController.scrollToHeading(
          headingIndex,
          topOffset: _jumpTopOffset,
        );
      }
    }
  }

  void _flashLineHighlight(int lineNumber) {
    if (!mounted || _mode != EditorMode.edit) return;
    setState(() => _highlightedLine = lineNumber);
    _highlightController.forward(from: 0.0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _highlightedLine = null);
      });
    });
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
    _textController.dispose();
    _searchController.dispose();
    _editScrollController.dispose();
    _undoController.dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _showInlineSearch() {
    if (_showToc) {
      _tocOverlayController.close();
    }

    setState(() {
      _showSearchBar = true;
    });

    _performInlineSearch(_searchController.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onSearchFocusChanged() {
    if (!mounted || !_showSearchBar) return;
    setState(() {
      _showSearchCandidates =
          _searchFocusNode.hasFocus && _searchController.text.trim().isNotEmpty;
    });
  }

  void _performInlineSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _searchMatches = const [];
        _activeSearchMatchIndex = -1;
        _showSearchCandidates = false;
      });
      return;
    }

    final text = _textController.text;
    final normalizedText = text.toLowerCase();
    final matches = <_SearchMatch>[];
    var index = 0;

    while (matches.length < 50) {
      index = normalizedText.indexOf(normalizedQuery, index);
      if (index == -1) break;
      final start = (index - 20).clamp(0, text.length);
      final end = (index + normalizedQuery.length + 20).clamp(0, text.length);
      final preview = text.substring(start, end).replaceAll('\n', ' ');
      matches.add(_SearchMatch(
        position: index,
        length: normalizedQuery.length,
        preview: preview,
        occurrence: matches.length,
      ));
      index += normalizedQuery.length;
    }

    setState(() {
      _searchMatches = matches;
      _activeSearchMatchIndex = matches.isEmpty ? -1 : 0;
      _showSearchCandidates = _searchFocusNode.hasFocus;
    });
  }

  void _jumpToSearchMatch(_SearchMatch match) {
    _jumpToSearchOccurrence(match.occurrence);
  }

  void _jumpToSearchOccurrence(int occurrence) {
    if (_searchMatches.isEmpty) return;
    final clamped = occurrence.clamp(0, _searchMatches.length - 1).toInt();
    final match = _searchMatches[clamped];
    if (_mode == EditorMode.preview) {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _previewWebViewController.execCmd(
          'search_jump',
          args: {
            'query': query,
            'occurrence': clamped,
          },
        );
      }
      setState(() => _activeSearchMatchIndex = clamped);
      return;
    }

    final position = match.position;
    final length = match.length;
    _textController.selection = TextSelection(
      baseOffset: position,
      extentOffset: position + length,
    );

    final lineNumber = (_textController.text
            .substring(0, position)
            .split('\n')
            .length
            .clamp(1, 1 << 20) -
        1)
        .toInt();
    _flashLineHighlight(lineNumber);

    if (_editScrollController.hasClients) {
      final lines = _textController.text.substring(0, position).split('\n');
      const lineHeight = 24.0;
      final targetScroll = (lines.length * lineHeight - _jumpTopOffset);
      _editScrollController.jumpTo(
        targetScroll.clamp(
          0.0,
          _editScrollController.position.maxScrollExtent,
        ),
      );
    }

    setState(() => _activeSearchMatchIndex = clamped);
  }

  void _jumpToNextSearchMatch() {
    if (_searchMatches.isEmpty) return;
    final next = _activeSearchMatchIndex < 0
        ? 0
        : (_activeSearchMatchIndex + 1) % _searchMatches.length;
    _jumpToSearchOccurrence(next);
  }

  void _jumpToPrevSearchMatch() {
    if (_searchMatches.isEmpty) return;
    final prev = _activeSearchMatchIndex < 0
        ? 0
        : (_activeSearchMatchIndex - 1 + _searchMatches.length) %
            _searchMatches.length;
    _jumpToSearchOccurrence(prev);
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
          filePath: widget.filePath,
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
            lines[i] =
                '${uncheckedMatch.group(1)}[x]${uncheckedMatch.group(2)}';
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

    if (href.startsWith('#')) {
      final rawFragment = Uri.decodeComponent(href.substring(1)).trim();
      if (rawFragment.isNotEmpty) {
        final normalizedFragment = _slugifyHeading(rawFragment);
        for (final item in _tocItems) {
          if (_slugifyHeading(item.title) == normalizedFragment) {
            _jumpToHeading(item);
            return;
          }
        }
      }
      return;
    }

    // Handle local markdown file links
    if (href.endsWith('.md') || href.endsWith('.markdown')) {
      // Sanitize: reject path traversal attempts
      if (!href.contains('..')) {
        final baseDir = File(widget.filePath).parent.path;
        final targetPath =
            '$baseDir${Platform.pathSeparator}${href.replaceAll('/', Platform.pathSeparator)}';
        final targetFile = File(targetPath);
        if (targetFile.existsSync()) {
          EditorNavigationHelper.openEditor(context, targetPath);
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

  String _slugifyHeading(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^\d+[\.\-_\s]+'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  // ==================== Block Parsing & Inline Editing ====================

  void _handleMilkdownContentChange(String markdown) {
    if (markdown == _textController.text) return;
    _textController.removeListener(_onTextChanged);
    _textController.text = markdown;
    _textController.addListener(_onTextChanged);
    _onTextChanged();
  }

  /// Parse markdown text into logical blocks for inline editing.
  /// Code blocks, tables, blockquotes, and nested list continuations are grouped.
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
        while (end < lines.length &&
            !_codeBlockStartRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        if (end < lines.length) end++; // include closing ```
        blocks.add(
          _MarkdownBlock(
            startLine: i,
            endLine: end - 1,
            content: lines.sublist(i, end).join('\n'),
            isMultiLine: true,
          ),
        );
        i = end;
        continue;
      }

      // Table: contiguous | lines (need at least 2 rows)
      if (_tableRowRegex.hasMatch(trimmed) &&
          i + 1 < lines.length &&
          _tableRowRegex.hasMatch(lines[i + 1].trim())) {
        int end = i;
        while (end < lines.length &&
            _tableRowRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        blocks.add(
          _MarkdownBlock(
            startLine: i,
            endLine: end - 1,
            content: lines.sublist(i, end).join('\n'),
            isMultiLine: true,
          ),
        );
        i = end;
        continue;
      }

      // Blockquote: contiguous > lines
      if (_blockquoteRegex.hasMatch(trimmed)) {
        int end = i;
        while (end < lines.length &&
            _blockquoteRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        blocks.add(
          _MarkdownBlock(
            startLine: i,
            endLine: end - 1,
            content: lines.sublist(i, end).join('\n'),
            isMultiLine: end > i + 1,
          ),
        );
        i = end;
        continue;
      }

      // Nested list/continuation block:
      // Group a list item with its indented continuation lines (including
      // nested markers) so single-tap editing on nested markdown replaces the
      // whole logical unit instead of only one rendered <li>/<p> fragment.
      if (_listItemStartRegex.hasMatch(trimmed)) {
        int end = i + 1;
        while (end < lines.length) {
          final next = lines[end];
          final nextTrim = next.trim();
          if (nextTrim.isEmpty) {
            end++;
            continue;
          }
          final isIndented = _indentedContentRegex.hasMatch(next);
          final isNestedListMarker = _nestedListMarkerRegex.hasMatch(next);
          if (!isIndented && !isNestedListMarker) break;
          end++;
        }
        blocks.add(
          _MarkdownBlock(
            startLine: i,
            endLine: end - 1,
            content: lines.sublist(i, end).join('\n'),
            isMultiLine: end > i + 1,
          ),
        );
        i = end;
        continue;
      }

      // Single line
      blocks.add(
        _MarkdownBlock(
          startLine: i,
          endLine: i,
          content: line,
          isMultiLine: false,
        ),
      );
      i++;
    }

    return blocks;
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
        final caretOffset = newLines
            .take(block.startLine + editedLines.length)
            .join('\n')
            .length
            .clamp(0, newText.length)
            .toInt();
        _applyMainTextWithSelection(
          newText,
          TextSelection.collapsed(offset: caretOffset),
        );
        // _isModified will be set by _onTextChanged listener
      }
    }
  }

  /// Build the WebView-based preview for EditorMode.preview.
  Widget _buildInlineEditablePreview(SettingsProvider settings) {
    if (_hidePlatformViews) return const SizedBox.expand();
    return MilkdownWebViewEditor(
      initialMarkdown: _textController.text,
      readOnly: false,
      fontSize: settings.fontSize,
      bodyFont: settings.editorFontFamily == 'System'
          ? null
          : settings.editorFontFamily,
      monoFont: settings.codeFontFamily == 'System'
          ? null
          : settings.codeFontFamily,
      baseDirectory: File(widget.filePath).parent.path,
      onContentChange: _handleMilkdownContentChange,
      onOutlineUpdate: _handleOutlineUpdate,
      onLinkClick: (payload) => _handleLinkTap(
        payload.text ?? '',
        payload.href,
        payload.title ?? '',
      ),
      onCheckboxToggle: _toggleCheckbox,
      controller: _previewWebViewController,
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
                  controller: _tocOverlayController,
                ),
              // Floating buttons – positioned relative to the full screen so
              // they stay fixed even when the keyboard is shown.
              if (!_isLoading && _error == null) _buildFixedFloatingButtons(),
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
            bottom: false,
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
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildContent()),
                      if (_showSearchBar)
                        Positioned(
                          top: 10,
                          left: 12,
                          right: 12,
                          child: _buildInlineSearch(),
                        ),
                      // Toolbar floats at the bottom of the content area
                      if (!_isLoading &&
                          _error == null &&
                          (_mode != EditorMode.preview ||
                              _editingBlockIndex != null))
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: MarkdownToolbar(
                            controller: _editingBlockIndex != null
                                ? _inlineEditController
                                : _textController,
                            undoController: _editingBlockIndex != null
                                ? null
                                : _undoController,
                            canUndo: _editingBlockIndex != null
                                ? _historyIndex > 0
                                : null,
                            canRedo: _editingBlockIndex != null
                                ? (_historyIndex >= 0 && _historyIndex < _editHistory.length - 1)
                                : null,
                            onUndo: _editingBlockIndex != null ? _undoEditHistory : null,
                            onRedo: _editingBlockIndex != null ? _redoEditHistory : null,
                            filePath: widget.filePath,
                            onSearchPressed: _showInlineSearch,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 粒子效果层（全局模式时显示）
          if (settings.particleEnabled && settings.particleGlobal)
            Positioned.fill(
              child: IgnorePointer(
                child: TickerMode(
                  enabled: true,
                  child: ParticleEffectWidget(
                    particleType: settings.particleType,
                    speed: settings.particleSpeed,
                    enabled: true,
                  ),
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
    final glyphs = text.runes.where((char) {
      final value = String.fromCharCode(char);
      return value.trim().isNotEmpty;
    }).length;
    final words = text.split(_wordSplitRegex).where((w) => w.isNotEmpty).length;
    return '$chars 字符 · $glyphs 文字 · $words 单词';
  }

  Widget _buildInlineSearch() {
    if (!_showSearchBar) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final appStyle = theme.extension<AppStyleTheme>()!;
    final displayMatches = _searchMatches.take(5).toList(growable: false);
    final showCandidates =
        _showSearchCandidates && _searchController.text.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: appStyle.scaledSurfaceColor(
                theme.colorScheme,
                alpha: 0.97,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              onChanged: _performInlineSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索内容...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: '关闭搜索',
                  icon: const Icon(Icons.close),
                onPressed: () {
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    _performInlineSearch('');
                    _searchFocusNode.requestFocus();
                      return;
                    }
                    _searchFocusNode.unfocus();
                    setState(() {
                      _showSearchBar = false;
                      _searchMatches = const [];
                      _activeSearchMatchIndex = -1;
                      _showSearchCandidates = false;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: appStyle.scaledSurfaceColor(
                theme.colorScheme,
                alpha: 0.95,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _searchMatches.isEmpty
                        ? '未找到匹配'
                        : '${_activeSearchMatchIndex + 1}/${_searchMatches.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: '上一个',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      _searchMatches.isEmpty ? null : _jumpToPrevSearchMatch,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: '下一个',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      _searchMatches.isEmpty ? null : _jumpToNextSearchMatch,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: showCandidates
                  ? Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: appStyle.scaledSurfaceColor(
                          theme.colorScheme,
                          alpha: 0.98,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 120),
                        child: displayMatches.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  '未找到匹配内容',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: displayMatches.length,
                                itemBuilder: (context, index) {
                                  final match = displayMatches[index];
                                  return _buildSearchCandidateTile(match);
                                },
                              ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCandidateTile(_SearchMatch match) {
    final isActive = match.occurrence == _activeSearchMatchIndex;
    return ListTile(
      dense: true,
      selected: isActive,
      title: Text(
        match.preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _jumpToSearchMatch(match),
    );
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.red),
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
        // Top rounded corners at AppBar junction; clip ensures rounded corners
        // are visible on the WebView (platform view).
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: _buildEditPanel(settings, toolbarPadding: 56),
          ),
        );
      case EditorMode.preview:
        // Top rounded corners at AppBar junction.
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: _buildInlineEditablePreview(settings),
          ),
        );
    }
  }

  /// Floating action buttons that stay as fixed as possible at the
  /// bottom-right corner of the screen. The viewInsets compensation formula
  /// minimises vertical movement when the keyboard appears/disappears.
  Widget _buildFixedFloatingButtons() {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    switch (_mode) {
      case EditorMode.edit:
        // Keep button above the 56 px toolbar + 16 px gap.
        // Compensate for body shrinkage so the button stays as close as
        // possible to its natural position on screen.
        final editBottom = math.max(
          56.0 + 16.0,
          safeBottom + 56.0 + 16.0 - viewInsets,
        );
        return Positioned(
          right: 24,
          bottom: editBottom,
          child: _AnimatedFAB(
            icon: Icons.visibility,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => setState(() => _mode = EditorMode.preview),
          ),
        );
      case EditorMode.preview:
        if (_editingBlockIndex != null) return const SizedBox.shrink();
        // Keep buttons at a fixed visual position from the screen bottom.
        final previewBottom = math.max(8.0, safeBottom + 24.0 - viewInsets);
        return Positioned(
          right: 24,
          bottom: previewBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedFAB(
                icon: Icons.edit,
                color: Theme.of(context).colorScheme.tertiary,
                onTap: () => setState(() => _mode = EditorMode.edit),
              ),
              const SizedBox(height: 12),
              _AnimatedFAB(
                icon: Icons.list,
                color: Theme.of(context).colorScheme.primary,
                onTap: () {
                  if (_showToc) {
                    _tocOverlayController.close();
                    return;
                  }
                  setState(() => _showToc = true);
                },
              ),
            ],
          ),
        );
    }
  }

  Widget _buildEditPanel(
    SettingsProvider settings, {
    double toolbarPadding = 0,
  }) {
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
            fontFamily: settings.editorFontFamily == 'System'
                ? null
                : settings.editorFontFamily,
            height: 1.5,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + toolbarPadding,
            ),
            hintText: '开始编写你的 Markdown 内容...',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
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

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings() {
    return <ShortcutActivator, VoidCallback>{};
  }

  void _showMoreMenu() {
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
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索'),
              onTap: () {
                Navigator.pop(context);
                _showInlineSearch();
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('正在生成 PDF...')));
                await ExportService.exportAndShareAsPdf(
                  _textController.text,
                  widget.filePath
                      .split(Platform.pathSeparator)
                      .last
                      .replaceAll('.md', ''),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Animated Floating Action Button
// ──────────────────────────────────────────────────────────────────────────────

/// A floating action button with a scale-down press animation and a colour
/// glow shadow that intensifies when pressed.
class _AnimatedFAB extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedFAB({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _pressed
                ? widget.color.withValues(alpha: 0.85)
                : widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _pressed ? 0.6 : 0.4),
                blurRadius: _pressed ? 18 : 12,
                offset: _pressed ? const Offset(0, 2) : const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
