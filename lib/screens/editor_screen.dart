import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/editor_navigation_helper.dart';
import '../utils/app_style.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/milkdown_webview_editor.dart';
import '../widgets/particle_effect_widget.dart';
import '../models/toc_item.dart';
import '../models/milkdown_bridge.dart';
import 'editor/components/editor_header.dart';
import 'editor/components/toc_overlay.dart';
import 'editor/components/editor_search_bar.dart';
import 'editor/components/animated_fab.dart';
import 'editor/components/shortcuts_help_dialog.dart';
import 'editor/models/editor_models.dart';
import 'editor/models/editor_patterns.dart';
import 'editor/models/markdown_parser.dart';
import 'editor/editor_shortcuts.dart';
import '../services/export_service.dart';
import '../services/debug_probe_service.dart';

enum EditorMode { edit, preview }

class EditorScreen extends StatefulWidget {
  final String filePath;
  final String? initialContent;

  const EditorScreen({super.key, required this.filePath, this.initialContent});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  // ==================== 状态变量 ====================
  static const int _maxEditHistory = 100;
  final List<EditHistoryEntry> _editHistory = [];
  int _historyIndex = -1;
  bool _isApplyingHistory = false;
  bool _textListenerAttached = false;

  late TextEditingController _textController;
  late TextEditingController _searchController;
  late ScrollController _editScrollController;
  late UndoHistoryController _undoController;
  late FocusNode _searchFocusNode;
  late FocusNode _editFocusNode;
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;
  bool _editSelectionListenerAttached = false;

  /// 搜索防抖 Timer
  Timer? _searchDebounceTimer;

  final _previewWebViewController = MilkdownWebViewController();

  int? _editingBlockIndex;
  late TextEditingController _inlineEditController;
  late FocusNode _inlineEditFocusNode;

  EditorMode _mode = EditorMode.preview;
  bool _isLoading = true;
  bool _isModified = false;
  bool _isSaving = false;
  bool _isMilkdownEditorFocused = false;
  bool _showToc = false;
  bool _showSearchBar = false;
  bool _showSearchCandidates = false;
  final TocOverlayController _tocOverlayController = TocOverlayController();
  bool _hidePlatformViews = false;
  Timer? _autoSaveTimer;
  int? _highlightedLine;
  List<SearchMatch> _searchMatches = const [];
  int _activeSearchMatchIndex = -1;
  DateTime? _lastDebugProbeAt;
  bool _suppressNextMilkdownReload = false;

  // Undo/redo feedback state
  String? _lastActionFeedback;
  Timer? _actionFeedbackTimer;

  String? _error;
  List<TocItem> _tocItems = [];

  static const _jumpTopOffset = 32.0;

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _searchController = TextEditingController();
    _editScrollController = ScrollController();
    _undoController = UndoHistoryController();
    _searchFocusNode = FocusNode();
    _editFocusNode = FocusNode();
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
    _attachEditSelectionListener();
    if (widget.initialContent != null) {
      _applyLoadedContent(widget.initialContent!);
      _configureAutoSave();
      _isLoading = false;
    } else {
      _loadFile();
    }
    DebugProbeService.instance.registerCodeBlockLanguageProbe(
      _requestCodeBlockLanguageProbe,
    );
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

  void _attachEditSelectionListener() {
    if (_editSelectionListenerAttached) return;
    _editSelectionListenerAttached = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editSelectionListenerAttached) return;
      _textController.addListener(_onEditSelectionChanged);
    });
  }

  void _onEditSelectionChanged() {
    if (_mode != EditorMode.edit) return;
    if (!_editFocusNode.hasFocus) return;
    final selection = _textController.selection;
    if (!selection.isValid) return;
    _scheduleEditScrollToCursor();
  }

  Timer? _editScrollTimer;

  void _scheduleEditScrollToCursor() {
    _editScrollTimer?.cancel();
    _editScrollTimer = Timer(const Duration(milliseconds: 50), () {
      _scrollEditToCursor();
    });
  }

  void _scrollEditToCursor() {
    if (!mounted) return;
    if (_mode != EditorMode.edit) return;
    if (!_editFocusNode.hasFocus) return;

    final selection = _textController.selection;
    if (!selection.isValid) return;

    final text = _textController.text;
    final cursorOffset = selection.extentOffset;
    final settings = context.read<SettingsProvider>();
    final fontSize = settings.fontSize;
    final lineHeight = fontSize * 1.5;

    int lineCount = 0;
    int pos = 0;
    while (pos < cursorOffset && pos < text.length) {
      if (text[pos] == '\n') lineCount++;
      pos++;
    }

    const topPadding = 16.0;
    final estimatedY = topPadding + (lineCount * lineHeight);

    if (!_editScrollController.hasClients) return;
    final scrollPosition = _editScrollController.position;
    final viewportHeight = scrollPosition.viewportDimension;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    const toolbarHeight = 56.0;

    // 预留输入法遮挡的安全距离
    // 当键盘弹出时，输入法可能会遮挡部分区域
    // 添加预测性滚动边距，提前滚动避免光标进入遮挡区域
    const imeSafeMargin = 80.0;
    final bottomOffset = keyboardInset + toolbarHeight + imeSafeMargin;

    final visibleTop = scrollPosition.pixels;
    final visibleBottom = visibleTop + viewportHeight - bottomOffset;

    // 顶部安全边距：当光标接近顶部时提前滚动
    const topMargin = 100.0;
    // 底部预测边距：光标距离底部遮挡区域这个距离时就开始滚动
    final predictiveBottomMargin = lineHeight * 2;

    if (estimatedY < visibleTop + topMargin) {
      _editScrollController.animateTo(
        (estimatedY - topMargin).clamp(0.0, scrollPosition.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (estimatedY > visibleBottom - predictiveBottomMargin) {
      // 光标即将进入底部遮挡区域，提前滚动
      _editScrollController.animateTo(
        (estimatedY - viewportHeight + bottomOffset + predictiveBottomMargin)
            .clamp(0.0, scrollPosition.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
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
        ..add(EditHistoryEntry(text: t, selection: safe));
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

    _editHistory.add(EditHistoryEntry(text: t, selection: safe));
    if (_editHistory.length > _maxEditHistory) {
      final overflow = _editHistory.length - _maxEditHistory;
      _editHistory.removeRange(0, overflow);
      _historyIndex = (_historyIndex - overflow).clamp(
        0,
        _editHistory.length - 1,
      );
    }
    _historyIndex = _editHistory.length - 1;
    if (mounted) setState(() {});
  }

  TextSelection _safeSelection(TextSelection sel, int textLength) {
    final base = sel.baseOffset.clamp(0, textLength).toInt();
    final extent = sel.extentOffset.clamp(0, textLength).toInt();
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  void _undoEditHistory() {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    final entry = _editHistory[_historyIndex];
    _isApplyingHistory = true;
    _textController.value = TextEditingValue(
      text: entry.text,
      selection: entry.selection,
    );
    _isApplyingHistory = false;
    _showActionFeedback('已撤销');
    setState(() {});
  }

  void _redoEditHistory() {
    if (_historyIndex < 0 || _historyIndex >= _editHistory.length - 1) return;
    _historyIndex++;
    final entry = _editHistory[_historyIndex];
    _isApplyingHistory = true;
    _textController.value = TextEditingValue(
      text: entry.text,
      selection: entry.selection,
    );
    _isApplyingHistory = false;
    _showActionFeedback('已重做');
    setState(() {});
  }

  void _handleOutlineUpdate(OnOutlineUpdatePayload payload) {
    final items = payload.outline
        .map((node) {
          final lineNumber =
              int.tryParse(node.id.replaceFirst('line-', '')) ?? 0;
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

  void _jumpToHeading(int headingIndex, TocItem item) {
    if (_showToc) {
      _tocOverlayController.close();
    }

    if (_mode == EditorMode.edit) {
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
      if (headingIndex >= 0) {
        _previewWebViewController.scrollToHeading(
          headingIndex: headingIndex,
          lineNumber: item.lineNumber,
          headingText: item.title,
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

  void _showActionFeedback(String message) {
    _actionFeedbackTimer?.cancel();
    setState(() => _lastActionFeedback = message);
    _actionFeedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _lastActionFeedback = null);
    });
  }

  Future<void> _autoSave() async {
    if (_isModified && !_isSaving) {
      await _saveFile(showSnackbar: false);
    }
  }

  Future<void> _saveFile({bool showSnackbar = true}) async {
    final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.saveSuccess),
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
                Text(l10n.saveFailedWithError(e.toString())),
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
    DebugProbeService.instance.unregisterCodeBlockLanguageProbe(
      _requestCodeBlockLanguageProbe,
    );
    _autoSaveTimer?.cancel();
    _editScrollTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _actionFeedbackTimer?.cancel();

    // 移除所有 listener，使用标志位防止重复移除
    if (_textListenerAttached) {
      _textController.removeListener(_onTextChanged);
      _textListenerAttached = false;
    }
    if (_editSelectionListenerAttached) {
      _textController.removeListener(_onEditSelectionChanged);
      _editSelectionListenerAttached = false;
    }
    _textController.dispose();
    _searchController.dispose();
    _editScrollController.dispose();
    _undoController.dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _editFocusNode.dispose();
    _inlineEditFocusNode.removeListener(_onInlineEditFocusChanged);
    _inlineEditController.dispose();
    _inlineEditFocusNode.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final l10n = AppLocalizations.of(context)!;
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
            Expanded(
              child: Text(l10n.unsavedChanges, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Text(l10n.unsavedChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(l10n.discard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'save'),
            icon: const Icon(Icons.save, size: 18),
            label: Text(l10n.save),
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

  // ==================== 搜索功能 ====================

  void _showInlineSearch() {
    if (_showToc) {
      _tocOverlayController.close();
    }
    setState(() => _showSearchBar = true);
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

  /// 执行内联搜索（带防抖）
  void _performInlineSearch(String query) {
    // 取消之前的防抖 Timer
    _searchDebounceTimer?.cancel();

    // 延迟 150ms 执行搜索，避免频繁搜索
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      _executeSearch(query);

      // Clear or apply highlights in WebView
      if (_mode == EditorMode.preview) {
        if (query.trim().isEmpty) {
          _previewWebViewController.execCmd('search_clear');
        } else {
          _previewWebViewController.execCmd(
            'search_highlight',
            args: {'query': query.trim()},
          );
        }
      }
    });
  }

  /// 实际执行搜索
  void _executeSearch(String query) {
    if (!mounted) return;

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
    final matches = <SearchMatch>[];
    var index = 0;

    // 限制搜索时间，防止超大文件卡顿
    final startTime = DateTime.now();
    const maxSearchTime = Duration(milliseconds: 500);

    while (matches.length < 50) {
      // 检查是否超时
      if (DateTime.now().difference(startTime) > maxSearchTime) {
        debugPrint('搜索超时，已找到 ${matches.length} 个结果');
        break;
      }

      index = normalizedText.indexOf(normalizedQuery, index);
      if (index == -1) break;
      final start = (index - 20).clamp(0, text.length);
      final end = (index + normalizedQuery.length + 20).clamp(0, text.length);
      final preview = text.substring(start, end).replaceAll('\n', ' ');
      matches.add(
        SearchMatch(
          position: index,
          length: normalizedQuery.length,
          preview: preview,
          occurrence: matches.length,
        ),
      );
      index += normalizedQuery.length;
    }

    if (!mounted) return;

    setState(() {
      _searchMatches = matches;
      _activeSearchMatchIndex = matches.isEmpty ? -1 : 0;
      _showSearchCandidates =
          _searchFocusNode.hasFocus && normalizedQuery.isNotEmpty;
    });
  }

  void _jumpToSearchMatch(SearchMatch match) {
    _searchFocusNode.unfocus();
    if (_showSearchCandidates) {
      setState(() => _showSearchCandidates = false);
    }
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
          args: {'query': query, 'occurrence': clamped},
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

    final lineNumber =
        (_textController.text.substring(0, position).split('\n').length - 1)
            .clamp(0, 1 << 20)
            .toInt();
    _flashLineHighlight(lineNumber);

    if (_editScrollController.hasClients) {
      final lines = _textController.text.substring(0, position).split('\n');
      const lineHeight = 24.0;
      final targetScroll = lines.length * lineHeight - _jumpTopOffset;
      _editScrollController.jumpTo(
        targetScroll.clamp(0.0, _editScrollController.position.maxScrollExtent),
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

  void _closeSearch() {
    // Clear highlights in WebView
    if (_mode == EditorMode.preview) {
      _previewWebViewController.execCmd('search_clear');
    }

    setState(() {
      _showSearchBar = false;
      _searchMatches = const [];
      _activeSearchMatchIndex = -1;
      _showSearchCandidates = false;
    });
  }

  // ==================== 复选框和链接处理 ====================

  void _toggleCheckbox(int index, bool newValue) {
    final newText = toggleCheckboxInText(_textController.text, index, newValue);
    if (newText != null) {
      _previewWebViewController.suppressNextReload();
      _textController.removeListener(_onTextChanged);
      _textController.text = newText;
      _textController.addListener(_onTextChanged);
      setState(() => _isModified = true);
    }
  }

  void _handleLinkTap(String text, String? href, String title) {
    final normalizedHref = href?.trim() ?? '';
    final normalizedText = text.trim();
    final headingFragment = normalizedHref.startsWith('#')
        ? Uri.decodeComponent(normalizedHref.substring(1)).trim()
        : (normalizedHref.isEmpty ? normalizedText : '');

    if (headingFragment.isNotEmpty) {
      final normalizedFragment = slugifyHeading(headingFragment);
      for (var i = 0; i < _tocItems.length; i++) {
        final item = _tocItems[i];
        if (slugifyHeading(item.title) == normalizedFragment) {
          _jumpToHeading(i, item);
          return;
        }
      }
    }

    if (normalizedHref.isEmpty) return;

    if (normalizedHref.endsWith('.md') ||
        normalizedHref.endsWith('.markdown')) {
      if (!normalizedHref.contains('..')) {
        final baseDir = File(widget.filePath).parent.path;
        final targetPath =
            '$baseDir${Platform.pathSeparator}${normalizedHref.replaceAll('/', Platform.pathSeparator)}';
        final targetFile = File(targetPath);
        if (targetFile.existsSync()) {
          EditorNavigationHelper.openEditor(context, targetPath);
          return;
        }
      }
    }

    final uri = Uri.tryParse(normalizedHref);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('打开链接失败: $e');
      }
    }
  }

  void _showImagePreview(OnImageClickPayload payload) async {
    final src = payload.src;
    if (src.isEmpty) return;

    Widget imageWidget;

    if (src.startsWith('http://') ||
        src.startsWith('https://') ||
        src.startsWith('data:')) {
      // Network or data URL
      imageWidget = Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text('图片加载失败', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        },
      );
    } else {
      // Local file
      final file = File(src);
      if (await file.exists()) {
        imageWidget = Image.file(file, fit: BoxFit.contain);
      } else {
        imageWidget = Center(
          child: Text('文件不存在: $src', style: TextStyle(color: Colors.grey[600])),
        );
      }
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Image container
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                color: Colors.black87,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: imageWidget,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
            // Alt text (if available)
            if (payload.alt != null && payload.alt!.isNotEmpty)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payload.alt!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== Milkdown WebView ====================

  void _handleMilkdownContentChange(String markdown) {
    final suppressReload = _suppressNextMilkdownReload;
    _suppressNextMilkdownReload = false;
    if (markdown == _textController.text) return;
    if (suppressReload) {
      _previewWebViewController.suppressNextReload();
    }
    _textController.removeListener(_onTextChanged);
    _textController.text = markdown;
    _textController.addListener(_onTextChanged);
    _onTextChanged();
  }

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
      onLinkClick: (payload) =>
          _handleLinkTap(payload.text ?? '', payload.href, payload.title ?? ''),
      onImageClick: _showImagePreview,
      onCheckboxToggle: _toggleCheckbox,
      onBridgeMessage: _handleMilkdownBridgeMessage,
      controller: _previewWebViewController,
    );
  }

  void _handleMilkdownBridgeMessage(Map<String, dynamic> map) {
    final type = map['type']?.toString();
    if (type == 'on_content_change') {
      final payload = map['payload'];
      if (payload is Map) {
        _suppressNextMilkdownReload =
            payload['mode']?.toString() == 'code_sanitized';
      } else {
        _suppressNextMilkdownReload = false;
      }
    }
    final settings = context.read<SettingsProvider>();
    if (settings.debugEnabled) {
      settings.appendDebugLog('bridge<$type>: $map');
    }
    if (type == 'on_render_complete' && settings.debugEnabled) {
      _requestCodeBlockLanguageProbe();
      return;
    }
    if (type == 'on_debug_report') {
      final payload = map['payload'];
      settings.appendDebugLog('debug_report: $payload');
      return;
    }
    if (type != 'on_editor_focus') return;
    final payload = map['payload'];
    if (payload is! Map) return;
    final focused = payload['focused'] == true;
    if (!mounted || focused == _isMilkdownEditorFocused) return;
    setState(() => _isMilkdownEditorFocused = focused);
  }

  Future<void> _requestCodeBlockLanguageProbe() async {
    final now = DateTime.now();
    final last = _lastDebugProbeAt;
    if (last != null && now.difference(last).inMilliseconds < 900) return;
    _lastDebugProbeAt = now;
    await _previewWebViewController.execCmd(
      'debug_codeblock_language_report',
      args: {'source': 'editor_screen'},
    );
  }

  // ==================== 内联编辑 ====================

  void _finishInlineEdit() {
    if (_editingBlockIndex == null) return;

    final blocks = parseMarkdownBlocks(_textController.text);
    final editingIndex = _editingBlockIndex!;

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
      }
    }
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

  void _onInlineEditFocusChanged() {
    if (!_inlineEditFocusNode.hasFocus && _editingBlockIndex != null) {
      _finishInlineEdit();
    }
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isFocusMode = settings.focusMode;
    final shouldInterceptForMilkdownBlur =
        _mode == EditorMode.preview && _isMilkdownEditorFocused;
    final useCustomTitleBar =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return PopScope(
      canPop: !_isModified && !shouldInterceptForMilkdownBlur,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          if (mounted) setState(() => _hidePlatformViews = true);
          return;
        }
        if (shouldInterceptForMilkdownBlur) {
          await _previewWebViewController.execCmd('blur_editor');
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
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            if (useCustomTitleBar)
              CustomTitleBar(fileName: fileName, isEditorMode: true),
            Expanded(
              child: CallbackShortcuts(
                bindings: buildShortcutBindings(
                  onSave: _saveFile,
                  onUndo: _undoEditHistory,
                  onRedo: _redoEditHistory,
                  onSearch: _showInlineSearch,
                  onApplyAction: _applyToolbarAction,
                ),
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
                    if (!_isLoading && _error == null)
                      _buildFixedFloatingButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final isFocusMode = settings.focusMode;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

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
                if (!isFocusMode)
                  EditorHeader(
                    fileName: fileName,
                    fullFilePath: widget.filePath,
                    wordCount: _getWordCount(),
                    isModified: _isModified,
                    isSaving: _isSaving,
                    canUndo: _historyIndex > 0,
                    canRedo:
                        _historyIndex >= 0 &&
                        _historyIndex < _editHistory.length - 1,
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
                      Positioned.fill(child: _buildEditorWithGesture()),
                      if (_showSearchBar)
                        Positioned(
                          top: 10,
                          left: 12,
                          right: 12,
                          child: EditorSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            matches: _searchMatches,
                            activeMatchIndex: _activeSearchMatchIndex,
                            onSearch: _performInlineSearch,
                            onJumpToMatch: _jumpToSearchMatch,
                            onJumpToNext: _jumpToNextSearchMatch,
                            onJumpToPrevious: _jumpToPrevSearchMatch,
                            onClose: _closeSearch,
                            showCandidates: _showSearchCandidates,
                          ),
                        ),
                      if (!_isLoading &&
                          _error == null &&
                          (_mode != EditorMode.preview ||
                              _editingBlockIndex != null ||
                              _isMilkdownEditorFocused))
                        Positioned(
                          bottom: keyboardInset,
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
                                ? (_historyIndex >= 0 &&
                                      _historyIndex < _editHistory.length - 1)
                                : null,
                            onUndo: _editingBlockIndex != null
                                ? _undoEditHistory
                                : null,
                            onRedo: _editingBlockIndex != null
                                ? _redoEditHistory
                                : null,
                            filePath: widget.filePath,
                            onSearchPressed: _showInlineSearch,
                            onAction:
                                _mode == EditorMode.preview &&
                                    _editingBlockIndex == null
                                ? _handlePreviewToolbarAction
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_lastActionFeedback != null)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _lastActionFeedback!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          if (settings.particleEnabled &&
              settings.particleGlobal &&
              !settings.focusMode)
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
    final l10n = AppLocalizations.of(context)!;
    final text = _textController.text;
    final chars = text.length;
    final glyphs = text.runes.where((char) {
      final value = String.fromCharCode(char);
      return value.trim().isNotEmpty;
    }).length;
    final words = text.split(wordSplitRegex).where((w) => w.isNotEmpty).length;
    return l10n.wordCount(chars, glyphs, words);
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
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
                l10n.loadingFailed,
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
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return _buildEditor();
  }

  Widget _buildEditorWithGesture() {
    return GestureDetector(
      onDoubleTap: () {
        final settings = context.read<SettingsProvider>();
        settings.setFocusMode(!settings.focusMode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settings.focusMode ? '专注模式已开启' : '专注模式已关闭'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: _buildEditor(),
    );
  }

  Widget _buildEditor() {
    final settings = context.watch<SettingsProvider>();
    final editorBackground = _buildEditorBackgroundLayer(settings);

    switch (_mode) {
      case EditorMode.edit:
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (editorBackground != null) editorBackground,
              Container(
                color: editorBackground == null
                    ? Theme.of(context).colorScheme.surface
                    : Colors.transparent,
                child: _buildEditPanel(settings, toolbarPadding: 56),
              ),
            ],
          ),
        );
      case EditorMode.preview:
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (editorBackground != null) editorBackground,
              Container(
                color: editorBackground == null
                    ? Theme.of(context).colorScheme.surface
                    : Colors.transparent,
                child: _buildInlineEditablePreview(settings),
              ),
            ],
          ),
        );
    }
  }

  Widget? _buildEditorBackgroundLayer(SettingsProvider settings) {
    final path = settings.editorBackgroundImagePath;
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;

    Widget imageLayer = Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    final brightness = settings.editorBackgroundBrightness;
    if ((brightness - 1.0).abs() > 0.001) {
      imageLayer = ColorFiltered(
        colorFilter: ColorFilter.matrix([
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          brightness,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: imageLayer,
      );
    }

    if (settings.editorBackgroundBlurEnabled) {
      imageLayer = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: settings.editorBackgroundBlur,
          sigmaY: settings.editorBackgroundBlur,
        ),
        child: imageLayer,
      );
    }

    return imageLayer;
  }

  Widget _buildFixedFloatingButtons() {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    switch (_mode) {
      case EditorMode.edit:
        final editBottom = safeBottom + 56.0 + 16.0;
        return Positioned(
          right: 24,
          bottom: editBottom,
          child: AnimatedFab(
            icon: Icons.visibility,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => setState(() {
              _mode = EditorMode.preview;
              _isMilkdownEditorFocused = false;
            }),
          ),
        );
      case EditorMode.preview:
        if (_editingBlockIndex != null) return const SizedBox.shrink();
        final previewBottom = safeBottom + 24.0;
        return Positioned(
          right: 24,
          bottom: previewBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedFab(
                icon: Icons.edit,
                color: Theme.of(context).colorScheme.tertiary,
                onTap: () => setState(() {
                  _mode = EditorMode.edit;
                  _isMilkdownEditorFocused = false;
                }),
              ),
              const SizedBox(height: 12),
              AnimatedFab(
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
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        TextField(
          controller: _textController,
          scrollController: _editScrollController,
          undoController: _undoController,
          focusNode: _editFocusNode,
          maxLines: null,
          expands: true,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          scrollPhysics: const ClampingScrollPhysics(),
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
            hintText: l10n.startWriting,
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

  Future<void> _handlePreviewToolbarAction(MarkdownToolbarAction action) async {
    if (_mode != EditorMode.preview || _editingBlockIndex != null) return;
    if (action == MarkdownToolbarAction.search) {
      _showInlineSearch();
      return;
    }

    String? cmd;
    Map<String, dynamic>? args;
    switch (action) {
      case MarkdownToolbarAction.undo:
        cmd = 'undo';
        break;
      case MarkdownToolbarAction.redo:
        cmd = 'redo';
        break;
      case MarkdownToolbarAction.bold:
        cmd = 'toggle_bold';
        break;
      case MarkdownToolbarAction.italic:
        cmd = 'toggle_italic';
        break;
      case MarkdownToolbarAction.strikethrough:
        cmd = 'toggle_strikethrough';
        break;
      case MarkdownToolbarAction.heading1:
        cmd = 'set_heading';
        args = {'level': 1};
        break;
      case MarkdownToolbarAction.heading2:
        cmd = 'set_heading';
        args = {'level': 2};
        break;
      case MarkdownToolbarAction.heading3:
        cmd = 'set_heading';
        args = {'level': 3};
        break;
      case MarkdownToolbarAction.bulletList:
        cmd = 'toggle_bullet_list';
        break;
      case MarkdownToolbarAction.orderedList:
        cmd = 'toggle_ordered_list';
        break;
      case MarkdownToolbarAction.taskList:
        cmd = 'toggle_bullet_list';
        break;
      case MarkdownToolbarAction.blockquote:
        cmd = 'toggle_blockquote';
        break;
      case MarkdownToolbarAction.inlineCode:
        cmd = 'toggle_inline_code';
        break;
      case MarkdownToolbarAction.codeBlock:
        cmd = 'insert_code_block';
        break;
      case MarkdownToolbarAction.link:
        cmd = 'toggle_link';
        break;
      case MarkdownToolbarAction.image:
        cmd = 'insert_image_prompt';
        break;
      case MarkdownToolbarAction.horizontalRule:
        cmd = 'insert_hr';
        break;
      case MarkdownToolbarAction.table:
        cmd = 'insert_table';
        break;
      case MarkdownToolbarAction.search:
        break;
    }

    if (cmd == null) return;
    await _previewWebViewController.focusEditor();
    await _previewWebViewController.execCmd(cmd, args: args);
  }

  void _applyToolbarAction(MarkdownToolbarAction action) {
    if (_mode == EditorMode.edit) {
      // 工具栏自己处理
    } else {
      _handlePreviewToolbarAction(action);
    }
  }

  void _showMoreMenu() {
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(l10n.search),
              onTap: () {
                Navigator.pop(context);
                _showInlineSearch();
              },
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('快捷键帮助'),
              subtitle: const Text('查看所有可用快捷键'),
              onTap: () {
                Navigator.pop(context);
                showShortcutsHelpDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(l10n.exportAsPdf),
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.generatingPdf)));
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
