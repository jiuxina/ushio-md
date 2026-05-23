import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/editor_navigation_helper.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/milkdown_webview_editor.dart';
import '../widgets/particle_effect_widget.dart';
import '../models/toc_item.dart';
import '../models/milkdown_bridge.dart';
import '../services/search_history_service.dart';
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
import '../utils/debug_log.dart';
import '../utils/markdown_incremental_merge.dart';
import '../utils/responsive_layout.dart';
import '../services/cloud_sync_service.dart';
import '../services/webdav_service.dart';
import '../services/ftp_service.dart';
import '../services/my_files_service.dart';
import '../services/sync_service_interface.dart';
import '../services/version_service.dart';
import '../models/document_version.dart';
import 'editor/components/version_history_sheet.dart';
import 'editor/components/diff_view_overlay.dart';

enum EditorMode { edit, preview }

class EditorScreen extends StatefulWidget {
  final String filePath;
  final String? initialContent;

  const EditorScreen({super.key, required this.filePath, this.initialContent});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ==================== 状态变量 ====================
  static const int _maxEditHistory = 100;

  /// 根据文件大小动态限制历史步数
  int get _effectiveMaxHistory {
    final textLength = _textController.text.length;
    if (textLength > 100000) return 20; // > 100KB: 20 步
    if (textLength > 50000) return 50; // > 50KB: 50 步
    return _maxEditHistory; // 默认 100 步
  }

  final List<EditHistoryEntry> _editHistory = [];
  int _historyIndex = -1;
  bool _isApplyingHistory = false;
  bool _textListenerAttached = false;

  // ==================== 字数统计缓存 ====================
  int _cachedCharCount = 0;
  int _cachedGlyphCount = 0;
  int _cachedWordCount = 0;
  Timer? _wordCountDebounce;

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
  bool _isAutoSaving = false;
  DateTime? _lastSaveTime;
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
  SearchOptions _searchOptions = const SearchOptions();
  List<String> _searchHistory = [];
  final _searchHistoryService = SearchHistoryService();

  // Original Markdown for incremental merge (preserves original formatting)
  String _originalMarkdown = '';
  static const bool _enableIncrementalMerge = true;

  // Undo/redo feedback state
  String? _lastActionFeedback;
  Timer? _actionFeedbackTimer;

  // Floating buttons auto-hide state
  bool _floatingButtonsVisible = true;
  Timer? _hideFloatingButtonsTimer;

  String? _error;
  List<TocItem> _tocItems = [];
  int? _currentTocIndex;

  // ==================== 版本历史 ====================
  final _versionService = VersionService();
  final _versionHistoryController = VersionHistoryController();
  bool _showVersionHistoryOverlay = false;
  List<DocumentVersion> _versions = [];
  bool _isLoadingVersions = false;
  String? _versionErrorMessage;
  OverlayEntry? _diffOverlayEntry;
  bool _isRestoringVersion = false;

  static const _jumpTopOffset = 32.0;

  /// Hide floating buttons temporarily
  void _hideFloatingButtons() {
    final settings = context.read<SettingsProvider>();
    // Skip if mode is 'always' or 'never'
    if (settings.floatingButtonsMode != 'auto') return;

    _hideFloatingButtonsTimer?.cancel();
    if (_floatingButtonsVisible && mounted) {
      setState(() => _floatingButtonsVisible = false);
    }
  }

  /// Show floating buttons after delay
  void _showFloatingButtonsAfterDelay() {
    final settings = context.read<SettingsProvider>();
    // Skip if mode is 'always' or 'never'
    if (settings.floatingButtonsMode != 'auto') return;

    _hideFloatingButtonsTimer?.cancel();
    _hideFloatingButtonsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_floatingButtonsVisible) {
        setState(() => _floatingButtonsVisible = true);
      }
    });
  }

  /// Handle user interaction - hide buttons and schedule show
  void _onUserInteraction() {
    _hideFloatingButtons();
    _showFloatingButtonsAfterDelay();
  }

  void _onEditFocusChanged() {
    if (!mounted) return;
    // Hide floating buttons when edit field gains focus
    if (_editFocusNode.hasFocus && _mode == EditorMode.edit) {
      _hideFloatingButtons();
      _showFloatingButtonsAfterDelay();
    }
  }

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    appDebugLog('[EDITOR] initState called for: ${widget.filePath}');
    appDebugLog(
      '[EDITOR] initialContent provided: ${widget.initialContent != null}, length: ${widget.initialContent?.length ?? "N/A"}',
    );

    final initStopwatch = Stopwatch()..start();

    WidgetsBinding.instance.addObserver(this);

    // Save last opened file path for startup restore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      settings.setLastOpenedFilePath(widget.filePath);
    });

    _textController = TextEditingController();
    _searchController = TextEditingController();
    _editScrollController = ScrollController();
    _undoController = UndoHistoryController();
    _searchFocusNode = FocusNode();
    _editFocusNode = FocusNode();
    _editFocusNode.addListener(_onEditFocusChanged);
    _inlineEditController = TextEditingController();
    _inlineEditFocusNode = FocusNode();
    _inlineEditFocusNode.addListener(_onInlineEditFocusChanged);
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _attachEditSelectionListener();

    initStopwatch.stop();
    appDebugLog(
      '[EDITOR] Controllers initialized in ${initStopwatch.elapsedMilliseconds}ms',
    );

    // Load search history in background without blocking UI
    unawaited(_loadSearchHistory());

    if (widget.initialContent != null) {
      appDebugLog('[EDITOR] Using initialContent, skipping file load');
      _applyLoadedContent(widget.initialContent!);
      _configureAutoSave();
      _isLoading = false;
      appDebugLog('[EDITOR] initState complete (cached content)');
    } else {
      appDebugLog('[EDITOR] No initialContent, calling _loadFile()');
      _loadFile();
    }
  }

  Future<void> _loadSearchHistory() async {
    appDebugLog('[EDITOR] _loadSearchHistory starting...');
    final history = await _searchHistoryService.getHistory();
    appDebugLog('[EDITOR] _loadSearchHistory done, ${history.length} items');
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _loadFile() async {
    appDebugLog('[EDITOR] _loadFile starting...');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fileService = context.read<FileProvider>().fileService;
      appDebugLog('[EDITOR] Reading file: ${widget.filePath}');
      final loadStopwatch = Stopwatch()..start();
      final content = await fileService.readFile(widget.filePath);
      loadStopwatch.stop();
      appDebugLog(
        '[EDITOR] File read in ${loadStopwatch.elapsedMilliseconds}ms, length: ${content.length}',
      );

      if (!mounted) return;
      _applyLoadedContent(content);
      _configureAutoSave();
    } catch (e) {
      appDebugLog('[EDITOR] _loadFile ERROR: $e');
      _error = e.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      appDebugLog('[EDITOR] _loadFile complete, _isLoading = false');
    }
  }

  void _applyLoadedContent(String content) {
    appDebugLog(
      '[EDITOR] _applyLoadedContent called, length: ${content.length}',
    );
    _textController.text = content;
    // Store original markdown for incremental merge
    _originalMarkdown = content;
    if (!_textListenerAttached) {
      _textController.addListener(_onTextChanged);
      _textListenerAttached = true;
    }
    // 初始化字数统计缓存
    _cachedCharCount = content.length;
    _cachedGlyphCount = content.runes.where((char) {
      final value = String.fromCharCode(char);
      return value.trim().isNotEmpty;
    }).length;
    _cachedWordCount = content
        .split(wordSplitRegex)
        .where((w) => w.isNotEmpty)
        .length;
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
    // Skip scroll adjustment during IME composition to prevent cursor jumping
    if (_textController.value.composing != TextRange.empty) return;
    _scheduleEditScrollToCursor();
  }

  Timer? _editScrollTimer;

  void _scheduleEditScrollToCursor() {
    _editScrollTimer?.cancel();
    _editScrollTimer = Timer(const Duration(milliseconds: 50), () {
      _scrollEditToCursor();
    });
    // Hide floating buttons on scroll
    _onUserInteraction();
  }

  void _scrollEditToCursor() {
    if (!mounted) return;
    if (_mode != EditorMode.edit) return;
    if (!_editFocusNode.hasFocus) return;

    final selection = _textController.selection;
    if (!selection.isValid) return;

    final text = _textController.text;
    final cursorOffset = selection.extentOffset.clamp(0, text.length);
    final settings = context.read<SettingsProvider>();
    final fontSize = settings.fontSize;
    final lineHeight = fontSize * 1.5;

    // 使用 substring + split 计算行号，比逐字符遍历更快
    final lineCount = text.substring(0, cursorOffset).split('\n').length - 1;

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
    _scheduleWordCountUpdate();
  }

  void _scheduleWordCountUpdate() {
    _wordCountDebounce?.cancel();
    _wordCountDebounce = Timer(const Duration(milliseconds: 300), () {
      _updateWordCount();
    });
  }

  void _updateWordCount() {
    final text = _textController.text;
    _cachedCharCount = text.length;
    _cachedGlyphCount = text.runes.where((char) {
      final value = String.fromCharCode(char);
      return value.trim().isNotEmpty;
    }).length;
    _cachedWordCount = text
        .split(wordSplitRegex)
        .where((w) => w.isNotEmpty)
        .length;
    if (mounted) setState(() {});
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
    if (_editHistory.length > _effectiveMaxHistory) {
      final overflow = _editHistory.length - _effectiveMaxHistory;
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
    // Update current TOC index for highlighting
    setState(() => _currentTocIndex = headingIndex);

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
    // 如果正在回退版本，跳过自动保存
    if (_isRestoringVersion) return;
    if (_isModified && !_isSaving) {
      setState(() => _isAutoSaving = true);
      await _saveFile(showSnackbar: false, isAutoSave: true);
      if (mounted) {
        setState(() => _isAutoSaving = false);
      }
    }
  }

  Future<void> _saveFile({
    bool showSnackbar = true,
    bool isAutoSave = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final fileService = context.read<FileProvider>().fileService;
      await fileService.saveFile(widget.filePath, _textController.text);
      if (mounted) {
        // Update original markdown after successful save
        // This resets the baseline for future incremental merges
        _originalMarkdown = _textController.text;
        setState(() {
          _isModified = false;
          _lastSaveTime = DateTime.now();
        });
      }

      // 创建版本快照（失败不影响保存成功状态）
      _createVersionSnapshot();

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

      // 自动云同步
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        if (settings.autoSyncEnabled && settings.isSyncConfigured) {
          _triggerAutoSync();
        }
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

  /// 触发自动云同步（后台执行，不阻塞 UI）
  void _triggerAutoSync() async {
    try {
      final settings = context.read<SettingsProvider>();

      // 初始化同步服务
      SyncServiceInterface syncService;
      if (settings.syncType == 'webdav') {
        syncService = WebDAVService();
        if (settings.isWebdavConfigured) {
          syncService.setRemoteWorkspaceName(settings.syncFolderName);
          syncService.setRemotePathPrefix(settings.syncRemotePath);
          final creds = settings.getWebdavCredentials();
          (syncService as WebDAVService).initialize(
            WebDAVConfig(
              url: creds['url']!,
              username: creds['username']!,
              password: creds['password']!,
            ),
          );
        }
      } else {
        syncService = FTPService();
        if (settings.isFtpConfigured) {
          syncService.setRemoteWorkspaceName(settings.syncFolderName);
          syncService.setRemotePathPrefix(settings.syncRemotePath);
          final creds = settings.getFtpCredentials();
          (syncService as FTPService).initialize(
            FTPConfig(
              host: settings.ftpHost,
              port: settings.ftpPort,
              username: creds['username']!,
              password: creds['password']!,
            ),
          );
        }
      }

      final myFilesService = MyFilesService();
      myFilesService.setSettingsProvider(settings);

      final cloudSyncService = CloudSyncService(
        syncService: syncService,
        myFilesService: myFilesService,
      );

      // 同步单个文件
      final success = await cloudSyncService.syncFile(widget.filePath);

      if (success) {
        settings.updateLastSyncTime();
        appDebugLog('[AutoSync] 文件同步成功: ${widget.filePath}');
      }

      cloudSyncService.dispose();
    } catch (e) {
      appDebugLog('[AutoSync] 同步失败: $e');
    }
  }

  // ==================== 版本历史 ====================

  /// 创建版本快照（后台执行，失败不影响保存状态）
  void _createVersionSnapshot() {
    unawaited(
      _versionService
          .createVersion(widget.filePath, _textController.text)
          .then((version) {
            appDebugLog('[Version] 版本快照创建成功: v${version.versionNumber}');
          })
          .catchError((e) {
            appDebugLog('[Version] 版本快照创建失败（不影响保存）: $e');
          }),
    );
  }

  /// 显示版本历史覆盖层
  Future<void> _showVersionHistory() async {
    setState(() {
      _showVersionHistoryOverlay = true;
      _isLoadingVersions = true;
      _versionErrorMessage = null;
    });

    try {
      final versions = await _versionService.getVersionHistory(widget.filePath);
      if (mounted) {
        setState(() {
          _versions = versions;
          _isLoadingVersions = false;
        });
      }
    } catch (e) {
      appDebugLog('[Version] 加载版本历史失败: $e');
      if (mounted) {
        setState(() {
          _versionErrorMessage = '加载版本历史失败';
          _isLoadingVersions = false;
        });
      }
    }
  }

  /// 关闭版本历史覆盖层
  void _closeVersionHistory() {
    if (mounted) {
      setState(() => _showVersionHistoryOverlay = false);
    }
  }

  /// 更新版本备注
  Future<void> _updateVersionNote(DocumentVersion version, String note) async {
    await _versionService.updateVersionNote(
      widget.filePath,
      version.versionNumber,
      note,
    );
    // 刷新版本列表
    final versions = await _versionService.getVersionHistory(widget.filePath);
    if (mounted) {
      setState(() {
        _versions = versions;
      });
    }
  }

  /// 显示未保存修改的 Diff 对比视图
  ///
  /// 对比 _originalMarkdown（上次保存的内容）与 _textController.text（当前内容）
  Future<void> _showUnsavedChangesDiff() async {
    try {
      // 获取最新版本信息用于显示
      final versions = await _versionService.getVersionHistory(widget.filePath);
      final latestVersion = versions.isNotEmpty ? versions.first : null;

      if (!mounted) return;

      // 创建"当前编辑中"的临时版本对象
      final currentEditingVersion = DocumentVersion(
        versionId: 'unsaved',
        versionNumber: latestVersion != null
            ? latestVersion.versionNumber + 1
            : 1,
        timestamp: DateTime.now(),
        note: '编辑中（未保存）',
        filePath: widget.filePath,
        versionPath: widget.filePath,
        fileSize: _textController.text.length,
      );

      _diffOverlayEntry = showDiffViewOverlay(
        context: context,
        oldVersion: latestVersion ?? currentEditingVersion,
        newVersion: currentEditingVersion,
        oldContent: _originalMarkdown,
        newContent: _textController.text,
        // 未保存修改视图中，回退按钮变为"丢弃修改"
        onRestore: (_) => _discardUnsavedChanges(),
        onCreateNewDoc: (_) {}, // 未保存修改不支持创建新文档
      );
    } catch (e) {
      appDebugLog('[Version] 加载未保存修改对比失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载对比失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 丢弃未保存的修改，恢复到上次保存的内容
  Future<void> _discardUnsavedChanges() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('丢弃修改'),
        content: const Text('确定要丢弃所有未保存的修改吗？\n此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('丢弃'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 恢复到上次保存的内容
    _textController.removeListener(_onTextChanged);
    _textController.text = _originalMarkdown;
    _textController.addListener(_onTextChanged);
    _recordHistorySnapshot(reset: true);

    setState(() {
      _isModified = false;
    });

    // 关闭 diff 视图
    _diffOverlayEntry?.remove();
    _diffOverlayEntry = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已丢弃未保存的修改'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 显示 Diff 对比视图
  ///
  /// Git 风格版本对比：
  /// - v1 是初始版本，无历史对比
  /// - vk (k>1) 显示 vk-1 与 vk 的差异
  Future<void> _showDiffView(DocumentVersion version) async {
    try {
      // v1 是初始版本，无历史对比
      if (version.versionNumber <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('v1 是初始版本，无历史对比'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 获取 vk-1 的内容（旧版本）
      final oldVersionContent = await _versionService.getVersionContent(
        widget.filePath,
        version.versionNumber - 1,
      );
      // 获取 vk 的内容（新版本）
      final newVersionContent = await _versionService.getVersionContent(
        widget.filePath,
        version.versionNumber,
      );

      if (!mounted) return;

      // 获取 vk-1 的版本信息
      final versions = await _versionService.getVersionHistory(widget.filePath);
      final oldVersion = versions.firstWhere(
        (v) => v.versionNumber == version.versionNumber - 1,
        orElse: () => version, // fallback，不应该发生
      );

      _diffOverlayEntry = showDiffViewOverlay(
        context: context,
        oldVersion: oldVersion, // vk-1
        newVersion: version, // vk
        oldContent: oldVersionContent,
        newContent: newVersionContent,
        onRestore: _restoreVersion,
        onCreateNewDoc: (_) => _createNewDocFromVersion(version),
      );
    } catch (e) {
      appDebugLog('[Version] 加载版本内容失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载版本内容失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 回退到指定版本
  Future<void> _restoreVersion(DocumentVersion version) async {
    // 移除 diff 覆盖层，避免遮挡确认对话框
    _diffOverlayEntry?.remove();

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
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
              child: const Icon(Icons.restore, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('确认回退版本', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Text('将回退到版本 v${version.versionNumber}，当前内容会自动备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('回退'),
          ),
        ],
      ),
    );

    // 用户取消，重新显示 diff 覆盖层
    if (confirmed != true) {
      _diffOverlayEntry = showDiffViewOverlay(
        context: context,
        oldVersion: version,
        newVersion: version,
        oldContent: '',
        newContent: '',
        onRestore: _restoreVersion,
        onCreateNewDoc: (_) => _createNewDocFromVersion(version),
      );
      return;
    }

    // 暂停自动保存，避免文件冲突
    _autoSaveTimer?.cancel();
    _isRestoringVersion = true;

    try {
      // 调用 VersionService 执行回退（内部会自动创建备份）
      final restoredVersion = await _versionService.restoreVersion(
        widget.filePath,
        version.versionNumber,
      );

      // 读取恢复后的内容并更新编辑器
      final restoredContent = await _versionService.getVersionContent(
        widget.filePath,
        version.versionNumber,
      );

      if (!mounted) return;

      // 更新编辑器内容和增量合并基准
      _textController.removeListener(_onTextChanged);
      _textController.text = restoredContent;
      _originalMarkdown = restoredContent;
      _textController.addListener(_onTextChanged);

      // 重置编辑历史
      _recordHistorySnapshot(reset: true);

      setState(() {
        _isModified = false;
        _lastSaveTime = DateTime.now();
      });

      // 关闭所有覆盖层
      _diffOverlayEntry?.remove();
      _diffOverlayEntry = null;
      _closeVersionHistory();

      // 显示成功提示（包含备份版本信息）
      final backupVersionNumber = restoredVersion.versionNumber - 1;
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
              Expanded(
                child: Text(
                  '已回退到 v${version.versionNumber}，备份为 v$backupVersionNumber',
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      appDebugLog('[Version] 版本回退失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('版本回退失败: $e')),
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
    } finally {
      // 恢复自动保存
      _isRestoringVersion = false;
      _configureAutoSave();
    }
  }

  /// 从版本创建新文档
  Future<void> _createNewDocFromVersion(DocumentVersion version) async {
    try {
      final newFilePath = await _versionService.createNewDocFromVersion(
        widget.filePath,
        version.versionNumber,
      );

      if (!mounted) return;

      // 关闭所有覆盖层
      _diffOverlayEntry?.remove();
      _diffOverlayEntry = null;
      _closeVersionHistory();

      // 跳转到新文档
      await EditorNavigationHelper.openEditor(context, newFilePath);
    } catch (e) {
      appDebugLog('[Version] 创建新文档失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建新文档失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _editScrollTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _actionFeedbackTimer?.cancel();
    _wordCountDebounce?.cancel();
    _hideFloatingButtonsTimer?.cancel();

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
    _editFocusNode
      ..removeListener(_onEditFocusChanged)
      ..dispose();
    _inlineEditFocusNode.removeListener(_onInlineEditFocusChanged);
    _inlineEditController.dispose();
    _inlineEditFocusNode.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  double _lastKeyboardInset = 0;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 使用 WidgetsBinding.instance.scheduleFrameCallback 确保在帧更新后获取正确的键盘高度
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (!mounted) return;
      final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
      // 键盘弹出时（高度增加），触发光标滚动
      if (keyboardInset > _lastKeyboardInset && keyboardInset > 0) {
        if (_mode == EditorMode.edit && _editFocusNode.hasFocus) {
          _scheduleEditScrollToCursor();
        }
      }
      _lastKeyboardInset = keyboardInset;
    });
  }

  Future<bool> _onWillPop() async {
    final l10n = AppLocalizations.of(context)!;
    if (_editingBlockIndex != null) {
      _finishInlineEdit();
    }
    if (!_isModified) return true;

    // 检查是否启用了退出时自动保存
    final settings = context.read<SettingsProvider>();
    if (settings.saveOnExit) {
      await _saveFile(showSnackbar: false);
      return true;
    }

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
            args: {
              'query': query.trim(),
              'caseSensitive': _searchOptions.caseSensitive,
              'wholeWord': _searchOptions.wholeWord,
              'useRegex': _searchOptions.useRegex,
            },
          );
        }
      }
    });
  }

  /// 实际执行搜索
  Future<void> _executeSearch(String query) async {
    if (!mounted) return;

    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _searchMatches = const [];
        _activeSearchMatchIndex = -1;
        _showSearchCandidates = false;
      });
      return;
    }

    final text = _textController.text;
    final matches = <SearchMatch>[];

    // 限制搜索时间，防止超大文件卡顿
    final startTime = DateTime.now();
    const maxSearchTime = Duration(milliseconds: 500);
    const maxResults = 100;

    try {
      if (_searchOptions.useRegex) {
        // 正则表达式搜索
        final regex = RegExp(
          normalizedQuery,
          caseSensitive: _searchOptions.caseSensitive,
        );
        for (final match in regex.allMatches(text)) {
          if (matches.length >= maxResults) break;
          if (DateTime.now().difference(startTime) > maxSearchTime) break;
          final start = (match.start - 20).clamp(0, text.length);
          final end = (match.end + 20).clamp(0, text.length);
          final preview = text.substring(start, end).replaceAll('\n', ' ');
          matches.add(
            SearchMatch(
              position: match.start,
              length: match.end - match.start,
              preview: preview,
              occurrence: matches.length,
            ),
          );
        }
      } else if (_searchOptions.wholeWord) {
        // 全词匹配
        final wordPattern = RegExp(
          r'\b' + RegExp.escape(normalizedQuery) + r'\b',
          caseSensitive: _searchOptions.caseSensitive,
        );
        for (final match in wordPattern.allMatches(text)) {
          if (matches.length >= maxResults) break;
          if (DateTime.now().difference(startTime) > maxSearchTime) break;
          final start = (match.start - 20).clamp(0, text.length);
          final end = (match.end + 20).clamp(0, text.length);
          final preview = text.substring(start, end).replaceAll('\n', ' ');
          matches.add(
            SearchMatch(
              position: match.start,
              length: match.end - match.start,
              preview: preview,
              occurrence: matches.length,
            ),
          );
        }
      } else {
        // 普通子串搜索
        final searchText = _searchOptions.caseSensitive
            ? text
            : text.toLowerCase();
        final searchQuery = _searchOptions.caseSensitive
            ? normalizedQuery
            : normalizedQuery.toLowerCase();
        var index = 0;

        while (matches.length < maxResults) {
          if (DateTime.now().difference(startTime) > maxSearchTime) {
            appDebugLog('搜索超时，已找到 ${matches.length} 个结果');
            break;
          }

          index = searchText.indexOf(searchQuery, index);
          if (index == -1) break;
          final start = (index - 20).clamp(0, text.length);
          final end = (index + searchQuery.length + 20).clamp(0, text.length);
          final preview = text.substring(start, end).replaceAll('\n', ' ');
          matches.add(
            SearchMatch(
              position: index,
              length: searchQuery.length,
              preview: preview,
              occurrence: matches.length,
            ),
          );
          index += searchQuery.length;
        }
      }
    } catch (e) {
      // 无效的正则表达式或其他错误
      appDebugLog('搜索错误: $e');
    }

    if (!mounted) return;

    // 添加到搜索历史（非阻塞，后台执行）
    if (matches.isNotEmpty) {
      unawaited(
        _searchHistoryService.addQuery(normalizedQuery).then((_) {
          if (mounted) return _loadSearchHistory();
        }),
      );
    }

    setState(() {
      _searchMatches = matches;
      _activeSearchMatchIndex = matches.isEmpty ? -1 : 0;
      _showSearchCandidates =
          _searchFocusNode.hasFocus && normalizedQuery.isNotEmpty;
    });
  }

  /// 更新搜索选项
  Future<void> _updateSearchOptions(SearchOptions options) async {
    if (_searchOptions == options) return;
    setState(() => _searchOptions = options);
    // 使用新选项重新搜索
    await _executeSearch(_searchController.text);
    // 更新 WebView 高亮
    if (_mode == EditorMode.preview) {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _previewWebViewController.execCmd(
          'search_highlight',
          args: {
            'query': query,
            'caseSensitive': options.caseSensitive,
            'wholeWord': options.wholeWord,
            'useRegex': options.useRegex,
          },
        );
      }
    }
  }

  /// 处理搜索历史选择
  Future<void> _onHistorySelected(String query) async {
    await _searchHistoryService.addQuery(query);
    await _loadSearchHistory();
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
    appDebugLog(
      '[CHECKBOX] Flutter _toggleCheckbox called: index=$index, newValue=$newValue',
    );
    final newText = toggleCheckboxInText(_textController.text, index, newValue);
    if (newText != null) {
      _previewWebViewController.suppressNextReload();
      _textController.removeListener(_onTextChanged);
      _textController.text = newText;
      _textController.addListener(_onTextChanged);
      setState(() => _isModified = true);
      appDebugLog('[CHECKBOX] Checkbox toggled successfully');
    } else {
      appDebugLog(
        '[CHECKBOX] toggleCheckboxInText returned null - checkbox not found',
      );
    }
  }

  void _handleLinkTap(String text, String? href, String title) {
    final normalizedHref = href?.trim() ?? '';
    final normalizedText = text.trim();

    // Handle anchor links (internal document links like #4-下载流程)
    if (normalizedHref.startsWith('#')) {
      // Safely decode URI component - may fail for non-encoded strings
      String headingFragment;
      try {
        headingFragment = Uri.decodeComponent(
          normalizedHref.substring(1),
        ).trim();
      } catch (e) {
        // If decoding fails, use the raw fragment
        headingFragment = normalizedHref.substring(1).trim();
        appDebugLog('[LINK] URI decode failed, using raw fragment: $e');
      }

      if (headingFragment.isNotEmpty) {
        appDebugLog('[LINK] href="$href" fragment="$headingFragment"');
        appDebugLog('[LINK] TOC items count: ${_tocItems.length}');
        for (var i = 0; i < _tocItems.length; i++) {
          final item = _tocItems[i];
          appDebugLog(
            '[LINK] TOC[$i]: title="${item.title}" slug="${slugifyHeading(item.title)}" line=${item.lineNumber}',
          );
        }

        // Try multiple matching strategies
        bool jumped = false;

        for (var i = 0; i < _tocItems.length; i++) {
          final item = _tocItems[i];
          final itemTitle = item.title;

          // Strategy 1: Direct slugified comparison
          final normalizedFragment = slugifyHeading(headingFragment);
          final normalizedTitle = slugifyHeading(itemTitle);
          if (normalizedTitle == normalizedFragment) {
            appDebugLog('[LINK] Matched by slug: "$normalizedTitle"');
            _jumpToHeading(i, item);
            jumped = true;
            break;
          }

          // Strategy 2: Match anchor fragment against original title (with number prefix)
          // e.g., "#4-下载流程" matches "4. 下载流程"
          final titleWithDot = itemTitle.trim();
          final anchorWithHyphen = headingFragment.replaceAll('-', ' ');
          if (slugifyHeading(titleWithDot) ==
              slugifyHeading(anchorWithHyphen)) {
            appDebugLog(
              '[LINK] Matched by normalized: "$titleWithDot" ~ "$anchorWithHyphen"',
            );
            _jumpToHeading(i, item);
            jumped = true;
            break;
          }

          // Strategy 3: Extract text content and compare
          // e.g., "#4-下载流程" -> "下载流程" matches "4. 下载流程" -> "下载流程"
          final fragmentTextOnly = headingFragment
              .replaceFirst(RegExp(r'^\d+[\.\-\s]+'), '')
              .replaceAll('-', ' ')
              .trim();
          final titleTextOnly = itemTitle
              .replaceFirst(RegExp(r'^\d+[\.\-\s]+'), '')
              .trim();
          if (slugifyHeading(fragmentTextOnly) ==
              slugifyHeading(titleTextOnly)) {
            appDebugLog(
              '[LINK] Matched by text: "$fragmentTextOnly" ~ "$titleTextOnly"',
            );
            _jumpToHeading(i, item);
            jumped = true;
            break;
          }
        }

        // Fallback: try to find heading by partial match or line number in anchor
        if (!jumped) {
          // Handle anchors like "#4-下载流程" where "4" might indicate heading number
          final lineMatch = RegExp(
            r'^(\d+)[\-\s\.]',
          ).firstMatch(headingFragment);
          if (lineMatch != null) {
            final targetLine = int.tryParse(lineMatch.group(1) ?? '');
            if (targetLine != null &&
                targetLine > 0 &&
                targetLine <= _tocItems.length) {
              appDebugLog('[LINK] Matched by line number: $targetLine');
              _jumpToHeading(targetLine - 1, _tocItems[targetLine - 1]);
              jumped = true;
            }
          }
        }

        // Final fallback: try direct scroll via WebView command
        if (!jumped) {
          appDebugLog('[LINK] No match found, trying scroll_to_anchor');
          _previewWebViewController.execCmd(
            'scroll_to_anchor',
            args: {'anchor': headingFragment},
          );
        }
      }
      return;
    }

    // Handle empty href - try to use link text as heading reference
    if (normalizedHref.isEmpty && normalizedText.isNotEmpty) {
      final normalizedFragment = slugifyHeading(normalizedText);
      for (var i = 0; i < _tocItems.length; i++) {
        final item = _tocItems[i];
        if (slugifyHeading(item.title) == normalizedFragment) {
          _jumpToHeading(i, item);
          return;
        }
      }
      return;
    }

    if (normalizedHref.isEmpty) return;

    // Handle .md file links
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

    // Handle external URLs
    final uri = Uri.tryParse(normalizedHref);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        appDebugLog('打开链接失败: $e');
      }
    }
  }

  void _showImagePreview(OnImageClickPayload payload) async {
    var src = payload.src;
    if (src.isEmpty) return;

    // Handle ushio-local-file:// scheme
    if (src.startsWith('ushio-local-file://')) {
      final uri = Uri.parse(src);
      src = uri.queryParameters['path'] ?? src;
    }

    // Resolve relative paths relative to the document's directory
    if (!src.startsWith('/') &&
        !src.startsWith('http://') &&
        !src.startsWith('https://') &&
        !src.startsWith('data:')) {
      final baseDir = File(widget.filePath).parent.path;
      src = '$baseDir${Platform.pathSeparator}$src';
    }

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
      var file = File(src);
      bool exists = await file.exists();

      // Try URL-decoded path if original doesn't exist
      if (!exists) {
        final decodedPath = Uri.decodeComponent(src);
        file = File(decodedPath);
        exists = await file.exists();
      }

      if (exists) {
        imageWidget = Image.file(file, fit: BoxFit.contain);
      } else {
        imageWidget = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('文件不存在', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                payload.src,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
    // Apply incremental merge to preserve original formatting
    String finalMarkdown = markdown;
    if (_enableIncrementalMerge && _originalMarkdown.isNotEmpty) {
      final result = incrementalMerge(
        original: _originalMarkdown,
        newContent: markdown,
      );
      finalMarkdown = result.content;

      // Log merge statistics for debugging
      if (result.hasChanges) {
        appDebugLog(
          '[INCREMENTAL_MERGE] Preserved ${result.preservedBlocks} blocks, '
          'replaced ${result.replacedBlocks} blocks',
        );
      }
    }

    if (finalMarkdown == _textController.text) return;
    // This change originated from the live Milkdown editor. Updating the
    // Flutter controller rebuilds this screen with a new initialMarkdown value,
    // but echoing that value back through init_doc would replace the ProseMirror
    // document and move the caret to the end while the user is typing.
    _previewWebViewController.suppressNextReload();
    _textController.removeListener(_onTextChanged);
    _textController.text = finalMarkdown;
    _textController.addListener(_onTextChanged);
    _onTextChanged();
  }

  Widget _buildInlineEditablePreview(SettingsProvider settings) {
    if (_hidePlatformViews) return const SizedBox.expand();
    return MilkdownWebViewEditor(
      initialMarkdown: _textController.text,
      readOnly: false,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      paragraphSpacing: settings.paragraphSpacing,
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
      codeBlockTheme:
          AppConstants.codeBlockThemes[settings.codeBlockThemeIndex].themeId,
    );
  }

  void _handleMilkdownBridgeMessage(Map<String, dynamic> map) {
    final type = map['type']?.toString();
    final settings = context.read<SettingsProvider>();
    if (settings.debugEnabled) {
      settings.appendDebugLog('bridge<$type>: $map');
    }
    if (type == 'on_debug_report') {
      final payload = map['payload'];
      settings.appendDebugLog('debug_report: $payload');
      return;
    }
    if (type == 'on_debug_log') {
      final payload = map['payload'];
      if (payload is Map) {
        settings.appendDebugLog('js: ${payload['message']}');
      }
      return;
    }
    if (type != 'on_editor_focus') return;
    final payload = map['payload'];
    if (payload is! Map) return;
    final focused = payload['focused'] == true;
    if (!mounted || focused == _isMilkdownEditorFocused) return;
    setState(() => _isMilkdownEditorFocused = focused);

    // Hide floating buttons when Milkdown editor gains focus
    if (focused) {
      _hideFloatingButtons();
      _showFloatingButtonsAfterDelay();
    }
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
    appDebugLog(
      '[EDITOR] build() called - _isLoading: $_isLoading, _error: $_error, _mode: $_mode',
    );

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
                  onEscape: _closeSearch,
                  onNextSearchMatch: _jumpToNextSearchMatch,
                  onPrevSearchMatch: _jumpToPrevSearchMatch,
                ),
                child: Stack(
                  children: [
                    _buildBody(),
                    if (!_isLoading && _error == null)
                      _buildFixedFloatingButtons(),
                    if (_showToc)
                      TocOverlay(
                        items: _tocItems,
                        onClose: () => setState(() => _showToc = false),
                        onJumpToHeading: _jumpToHeading,
                        controller: _tocOverlayController,
                        currentHeadingIndex: _currentTocIndex,
                        keepOpenOnJump: false,
                      ),
                    // 版本历史和 Diff 视图在浮动按钮之上
                    if (_showVersionHistoryOverlay)
                      VersionHistorySheet(
                        versions: _versions,
                        onClose: _closeVersionHistory,
                        onVersionSelected: _showDiffView,
                        onVersionNoteUpdated: _updateVersionNote,
                        controller: _versionHistoryController,
                        isLoading: _isLoadingVersions,
                        errorMessage: _versionErrorMessage,
                        isModified: _isModified,
                        onUnsavedChangesSelected: _showUnsavedChangesDiff,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopEditorFrame({required Widget child}) {
    if (!ResponsiveLayout.isDesktopWidth(context)) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveLayout.editorMaxWidth(context),
        ),
        child: child,
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
                    isAutoSaving: _isAutoSaving,
                    lastSaveTime: _lastSaveTime,
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
                      Positioned.fill(
                        child: _buildDesktopEditorFrame(
                          child: _buildEditorWithGesture(),
                        ),
                      ),
                      if (_showSearchBar)
                        Positioned(
                          top: 10,
                          left: ResponsiveLayout.isDesktopWidth(context)
                              ? 0
                              : 12,
                          right: ResponsiveLayout.isDesktopWidth(context)
                              ? 0
                              : 12,
                          child: _buildDesktopEditorFrame(
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
                              searchOptions: _searchOptions,
                              onOptionsChanged: _updateSearchOptions,
                              searchHistory: _searchHistory,
                              onHistorySelected: _onHistorySelected,
                            ),
                          ),
                        ),
                      // Toolbar with smooth slide-up animation
                      if (!_isLoading && _error == null && !isFocusMode)
                        Positioned(
                          bottom: keyboardInset,
                          left: 0,
                          right: 0,
                          child: _buildDesktopEditorFrame(
                            child: AnimatedSlide(
                              offset: Offset(
                                0,
                                (_mode != EditorMode.preview ||
                                        _editingBlockIndex != null ||
                                        _isMilkdownEditorFocused)
                                    ? 0
                                    : 1,
                              ),
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity:
                                    (_mode != EditorMode.preview ||
                                        _editingBlockIndex != null ||
                                        _isMilkdownEditorFocused)
                                    ? 1.0
                                    : 0.0,
                                duration: const Duration(milliseconds: 100),
                                curve: Curves.easeOut,
                                child: IgnorePointer(
                                  ignoring:
                                      !(_mode != EditorMode.preview ||
                                          _editingBlockIndex != null ||
                                          _isMilkdownEditorFocused),
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
                                              _historyIndex <
                                                  _editHistory.length - 1)
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
                              ),
                            ),
                          ),
                        ),
                      // Focus mode exit hint
                      if (isFocusMode)
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _FocusModeHint(
                              onHide: () {
                                final settings = context
                                    .read<SettingsProvider>();
                                settings.setFocusMode(false);
                              },
                            ),
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
                child: RepaintBoundary(
                  child: TickerMode(
                    enabled: true,
                    child: ParticleEffectWidget(
                      particleType: settings.particleType,
                      speed: settings.particleSpeed,
                      count: settings.particleCount,
                      size: settings.particleSize,
                      opacity: settings.particleOpacity,
                      wind: settings.particleWind,
                      enabled: true,
                    ),
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
    return l10n.wordCount(
      _cachedCharCount,
      _cachedGlyphCount,
      _cachedWordCount,
    );
  }

  Widget _buildEditorWithGesture() {
    return Listener(
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      onPointerUp: (_) => _showFloatingButtonsAfterDelay(),
      child: GestureDetector(
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
        behavior: HitTestBehavior.translucent,
        child: _buildEditor(),
      ),
    );
  }

  Widget _buildEditor() {
    final settings = context.watch<SettingsProvider>();
    final editorBackground = _buildEditorBackgroundLayer(settings);
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);

    switch (_mode) {
      case EditorMode.edit:
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isDesktop ? 12 : 20),
          ),
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isDesktop ? 12 : 20),
          ),
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
    if (path == null || !settings.editorBackgroundImageExists) return null;

    final file = File(path);

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
    final settings = context.watch<SettingsProvider>();
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final editorMaxWidth = ResponsiveLayout.editorMaxWidth(context);
    final desktopRightInset = isDesktop
        ? ((screenWidth - editorMaxWidth) / 2 + 24).clamp(24.0, double.infinity)
        : 24.0;

    // Check floating buttons mode
    final mode = settings.floatingButtonsMode;
    final bool showButtons;

    switch (mode) {
      case 'always':
        showButtons = true;
        break;
      case 'never':
        showButtons = false;
        break;
      case 'auto':
      default:
        showButtons = _floatingButtonsVisible;
        break;
    }

    switch (_mode) {
      case EditorMode.edit:
        final editBottom = safeBottom + 56.0 + 16.0;
        return Positioned(
          right: desktopRightInset,
          bottom: editBottom,
          child: AnimatedOpacity(
            opacity: showButtons ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: showButtons ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !showButtons,
                child: AnimatedFab(
                  icon: Icons.visibility,
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => setState(() {
                    _mode = EditorMode.preview;
                    _isMilkdownEditorFocused = false;
                  }),
                ),
              ),
            ),
          ),
        );
      case EditorMode.preview:
        if (_editingBlockIndex != null) return const SizedBox.shrink();
        final previewBottom = safeBottom + 24.0;
        return Positioned(
          right: desktopRightInset,
          bottom: previewBottom,
          child: AnimatedOpacity(
            opacity: showButtons ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: showButtons ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !showButtons,
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
              ),
            ),
          ),
        );
    }
  }

  Widget _buildEditPanel(
    SettingsProvider settings, {
    double toolbarPadding = 0,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    final hPad = isDesktop ? 24.0 : 16.0;
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
              hPad,
              16,
              hPad,
              16 + toolbarPadding,
            ),
            hintText: l10n.startWriting,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          onTap: _onUserInteraction,
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
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('查看历史'),
              subtitle: const Text('查看版本历史与对比'),
              onTap: () {
                Navigator.pop(context);
                _showVersionHistory();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Focus mode exit hint widget.
class _FocusModeHint extends StatefulWidget {
  final VoidCallback onHide;

  const _FocusModeHint({required this.onHide});

  @override
  State<_FocusModeHint> createState() => _FocusModeHintState();
}

class _FocusModeHintState extends State<_FocusModeHint> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _visible ? 1.0 : 0.0,
      child: GestureDetector(
        onTap: widget.onHide,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fullscreen_exit,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '双击退出专注模式',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
