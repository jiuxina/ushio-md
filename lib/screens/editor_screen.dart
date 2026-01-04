import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/markdown_toolbar.dart';

enum EditorMode { edit, preview, split }

class EditorScreen extends StatefulWidget {
  final String filePath;

  const EditorScreen({super.key, required this.filePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with TickerProviderStateMixin {
  late TextEditingController _textController;
  late ScrollController _editScrollController;
  late ScrollController _previewScrollController;
  late UndoHistoryController _undoController; // 撤回重做控制器

  EditorMode _mode = EditorMode.preview;
  bool _isLoading = true;
  bool _isModified = false;
  bool _isSaving = false;
  bool _showToc = false;
  Timer? _autoSaveTimer;
  Timer? _tocDebounceTimer; // TOC 更新防抖计时器
  String? _error;
  List<TocItem> _tocItems = [];

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editScrollController = ScrollController();
    _previewScrollController = ScrollController();
    _undoController = UndoHistoryController(); // 初始化撤回重做控制器
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
    // 防抖：用户停止输入 500ms 后再更新 TOC，减少性能开销
    _tocDebounceTimer?.cancel();
    _tocDebounceTimer = Timer(const Duration(milliseconds: 500), _updateToc);
  }

  void _updateToc() {
    final text = _textController.text;
    final lines = text.split('\n');
    final items = <TocItem>[];
    int lineNumber = 0;
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();
      
      // 检测代码块
      if (trimmedLine.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        lineNumber++;
        continue;
      }
      
      // 如果在代码块中，跳过
      if (inCodeBlock) {
        lineNumber++;
        continue;
      }

      // ATX 标题 (# Title) - 放宽匹配规则，允许无空格
      if (trimmedLine.startsWith('#')) {
        final match = RegExp(r'^(#{1,6})\s*(.+)$').firstMatch(trimmedLine);
        if (match != null) {
          final level = match.group(1)!.length;
          final title = match.group(2)!.trim();
          items.add(TocItem(
            level: level,
            title: title,
            lineNumber: lineNumber,
          ));
        }
      }
      // Setext 标题 (Title \n ===)
      else if (trimmedLine.isNotEmpty && i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.isNotEmpty) {
          if (RegExp(r'^=+$').hasMatch(nextLine)) {
            items.add(TocItem(
              level: 1,
              title: trimmedLine,
              lineNumber: lineNumber,
            ));
          } else if (RegExp(r'^-+$').hasMatch(nextLine)) {
            // 排除水平分割线（通常前面是空行）
            // 如果这一行是普通文本，下一行是---，则是二级标题
            items.add(TocItem(
              level: 2,
              title: trimmedLine,
              lineNumber: lineNumber,
            ));
          }
        }
      }
      lineNumber++;
    }

    setState(() => _tocItems = items);
  }

  void _jumpToHeading(TocItem item) {
    // Close TOC first
    setState(() => _showToc = false);

    // 计算标题在文本中的字符偏移量
    final lines = _textController.text.split('\n');
    int position = 0;
    // 累加标题之前的所有行的长度
    for (int i = 0; i < item.lineNumber && i < lines.length; i++) {
      position += lines[i].length + 1; // +1 是换行符
    }
    final totalLength = _textController.text.length;
    // 避免除以零
    final ratio = totalLength > 0 ? position / totalLength : 0.0;

    if (_mode == EditorMode.edit) {
      // In edit mode, move cursor and scroll
      _textController.selection = TextSelection.collapsed(offset: position);
      
      // Scroll edit panel based on char offset ratio
      if (_editScrollController.hasClients) {
        final maxScroll = _editScrollController.position.maxScrollExtent;
        final targetScroll = ratio * maxScroll;
        _editScrollController.animateTo(
          targetScroll.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // In preview or split mode, scroll preview panel based on char offset ratio
      if (_previewScrollController.hasClients) {
        final maxScroll = _previewScrollController.position.maxScrollExtent;
        final targetScroll = ratio * maxScroll;
        _previewScrollController.animateTo(
          targetScroll.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _autoSave() async {
    if (_isModified && !_isSaving) {
      await _saveFile(showSnackbar: false);
    }
  }

  Future<void> _saveFile({bool showSnackbar = true}) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final fileService = context.read<FileProvider>().fileService;
      await fileService.saveFile(widget.filePath, _textController.text);
      setState(() => _isModified = false);

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
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
    _tocDebounceTimer?.cancel(); // 释放 TOC 防抖计时器
    _textController.dispose();
    _editScrollController.dispose();
    _previewScrollController.dispose();
    _undoController.dispose(); // 释放撤回重做控制器
    super.dispose();
  }

  Future<bool> _onWillPop() async {
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
                color: Colors.orange.withOpacity(0.1),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isModified,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 防止输入法挤压界面
        body: Stack(
          children: [
            _buildBody(),
            // TOC overlay
            if (_showToc) _buildTocOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                ]
              : [
                  const Color(0xFFf8f9ff),
                  const Color(0xFFf0f4ff),
                ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildModeSelector(),
            if (!_isLoading && _error == null && _mode != EditorMode.preview)
              MarkdownToolbar(
                controller: _textController,
                undoController: _undoController,
                filePath: widget.filePath,
                onSearchPressed: _showSearchDialog,
              ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: () async {
              if (_isModified) {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isModified)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '未保存',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  _getWordCount(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  String _getWordCount() {
    final text = _textController.text;
    final chars = text.length;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return '$chars 字符 · $words 词';
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: _isModified
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              )
            : null,
        color: _isModified ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: _isModified
            ? null
            : Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
        boxShadow: _isModified
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSaving ? null : () => _saveFile(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSaving)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _isModified ? Colors.white : null,
                    ),
                  )
                else
                  Icon(
                    Icons.save,
                    size: 18,
                    color: _isModified ? Colors.white : null,
                  ),
                const SizedBox(width: 8),
                Text(
                  '保存',
                  style: TextStyle(
                    color: _isModified ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          _buildModeButton(EditorMode.preview, '预览', Icons.visibility),
          _buildModeButton(EditorMode.split, '分屏', Icons.vertical_split),
          _buildModeButton(EditorMode.edit, '编辑', Icons.edit),
        ],
      ),
    );
  }

  Widget _buildModeButton(EditorMode mode, String label, IconData icon) {
    final isSelected = _mode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                  color: Colors.red.withOpacity(0.1),
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
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildEditPanel(settings),
          ),
        );
      case EditorMode.preview:
        return Stack(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildPreviewPanel(settings),
              ),
            ),
            // 悬浮按钮组：搜索按钮 + 全屏按钮 + TOC按钮
            Positioned(
              right: 24,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 搜索按钮
                  _buildSearchButton(),
                  const SizedBox(height: 12),
                  // 全屏预览按钮
                  _buildFullscreenButton(),
                  const SizedBox(height: 12),
                  // 目录按钮（始终显示）
                  _buildTocButton(),
                ],
              ),
            ),
          ],
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
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
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
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
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

  /// 构建全屏预览按钮
  Widget _buildFullscreenButton({bool mini = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mini ? 12 : 16),
        onTap: _openFullscreenPreview,
        child: Container(
          padding: EdgeInsets.all(mini ? 10 : 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.secondary,
                Theme.of(context).colorScheme.tertiary,
              ],
            ),
            borderRadius: BorderRadius.circular(mini ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.fullscreen,
            color: Colors.white,
            size: mini ? 18 : 24,
          ),
        ),
      ),
    );
  }

  /// 打开全屏预览页面
  void _openFullscreenPreview() {
    final settings = context.read<SettingsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenPreviewPage(
          markdownContent: _textController.text,
          settings: settings,
          fileName: fileName,
        ),
      ),
    );
  }

  /// 构建搜索悬浮按钮
  Widget _buildSearchButton({bool mini = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mini ? 12 : 16),
        onTap: _showSearchDialog,
        child: Container(
          padding: EdgeInsets.all(mini ? 10 : 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal,
                Colors.cyan,
              ],
            ),
            borderRadius: BorderRadius.circular(mini ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.search,
            color: Colors.white,
            size: mini ? 18 : 24,
          ),
        ),
      ),
    );
  }

  /// 显示搜索对话框
  void _showSearchDialog() {
    final searchController = TextEditingController();
    List<int> matchPositions = [];
    int currentMatchIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void performSearch(String query) {
            if (query.isEmpty) {
              setModalState(() {
                matchPositions = [];
                currentMatchIndex = 0;
              });
              return;
            }

            final text = _textController.text.toLowerCase();
            final searchText = query.toLowerCase();
            final positions = <int>[];
            int index = 0;
            
            while (true) {
              index = text.indexOf(searchText, index);
              if (index == -1) break;
              positions.add(index);
              index += searchText.length;
            }

            setModalState(() {
              matchPositions = positions;
              currentMatchIndex = positions.isNotEmpty ? 0 : -1;
            });
          }

          void jumpToMatch(int position) {
            // 关闭对话框
            Navigator.pop(context);
            
            // 切换到编辑模式并跳转到匹配位置
            setState(() => _mode = EditorMode.edit);
            
            // 延迟执行以确保编辑器已渲染
            Future.delayed(const Duration(milliseconds: 100), () {
              final query = searchController.text;
              _textController.selection = TextSelection(
                baseOffset: position,
                extentOffset: position + query.length,
              );
              
              // 滚动到匹配位置
              if (_editScrollController.hasClients) {
                final lines = _textController.text.substring(0, position).split('\n');
                final lineHeight = 24.0; // 估算行高
                final targetScroll = lines.length * lineHeight;
                _editScrollController.animateTo(
                  targetScroll.clamp(0.0, _editScrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }

          // 获取键盘高度
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final screenHeight = MediaQuery.of(context).size.height;
          // 动态计算最大高度：屏幕高度 - 键盘高度 - 顶部安全边距
          final maxHeight = screenHeight - bottomInset - 100;
          
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset), // 适配输入法高度
            child: Container(
              constraints: BoxConstraints(
                maxHeight: maxHeight > 200 ? maxHeight : 200, // 确保最小高度
                minHeight: 200,
              ),
              // removing fixed height
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            child: Column(
              children: [
                // 拖动指示器
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 搜索输入框
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: '搜索内容...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: matchPositions.isNotEmpty
                                ? Text(
                                    '${currentMatchIndex + 1}/${matchPositions.length}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(minWidth: 60),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          onChanged: performSearch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 上一个/下一个按钮
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        onPressed: matchPositions.isEmpty ? null : () {
                          setModalState(() {
                            currentMatchIndex = (currentMatchIndex - 1 + matchPositions.length) % matchPositions.length;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: matchPositions.isEmpty ? null : () {
                          setModalState(() {
                            currentMatchIndex = (currentMatchIndex + 1) % matchPositions.length;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // 搜索结果列表
                Expanded(
                  child: matchPositions.isEmpty
                      ? Center(
                          child: Text(
                            searchController.text.isEmpty ? '输入关键词开始搜索' : '未找到匹配内容',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: matchPositions.length,
                          itemBuilder: (context, index) {
                            final position = matchPositions[index];
                            final text = _textController.text;
                            final start = (position - 20).clamp(0, text.length);
                            final end = (position + searchController.text.length + 20).clamp(0, text.length);
                            final context_ = text.substring(start, end).replaceAll('\n', ' ');

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: index == currentMatchIndex
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: index == currentMatchIndex
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              title: Text(
                                '...$context_...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap: () => jumpToMatch(position),
                            );
                          },
                        ),  // ListView.builder end
                ),  // Expanded end
              ],  // Column children end
            ),  // Column end
          ),  // Container end
        );  // Padding end
        },
      ),
    );
  }

  /// 切换checkbox状态
  /// [index] 是checkbox在markdown中的索引（从0开始）
  /// [newValue] 是新的选中状态
  void _toggleCheckbox(int index, bool newValue) {
    final text = _textController.text;
    final lines = text.split('\n');
    int checkboxCount = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // 匹配任务列表项: - [ ] 或 - [x] 或 - [X]
      final uncheckedMatch = RegExp(r'^(\s*-\s*)\[\s*\](.*)$').firstMatch(line);
      final checkedMatch = RegExp(r'^(\s*-\s*)\[[xX]\](.*)$').firstMatch(line);
      
      if (uncheckedMatch != null || checkedMatch != null) {
        if (checkboxCount == index) {
          // 找到目标checkbox，切换状态
          if (newValue) {
            // 从未选中切换到选中
            if (uncheckedMatch != null) {
              lines[i] = '${uncheckedMatch.group(1)}[x]${uncheckedMatch.group(2)}';
            }
          } else {
            // 从选中切换到未选中
            if (checkedMatch != null) {
              lines[i] = '${checkedMatch.group(1)}[ ]${checkedMatch.group(2)}';
            }
          }
          break;
        }
        checkboxCount++;
      }
    }
    
    // 更新文本内容
    final newText = lines.join('\n');
    if (newText != text) {
      setState(() {
        _textController.text = newText;
        _isModified = true;
      });
    }
  }

  Widget _buildTocButton({bool mini = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(mini ? 12 : 16),
        onTap: () => setState(() => _showToc = true),
        child: Container(
          padding: EdgeInsets.all(mini ? 10 : 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(mini ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.list,
            color: Colors.white,
            size: mini ? 18 : 24,
          ),
        ),
      ),
    );
  }

  Widget _buildTocOverlay() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return GestureDetector(
          onTap: () => setState(() => _showToc = false),
          child: Container(
            color: Colors.black.withOpacity(0.5 * value), // 背景淡入
            child: Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: Offset((1 - value) * 100, 0), // 从右侧滑入
                child: Opacity(
                  opacity: value,
                  child: GestureDetector(
                    onTap: () {}, // Prevent close on panel tap
                    child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.list,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '目录',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _showToc = false),
                        ),
                      ],
                    ),
                  ),
                  // TOC items
                  Expanded(
                    child: _tocItems.isEmpty
                        ? Center(
                            child: Text(
                              '没有找到标题',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _tocItems.length,
                            itemBuilder: (context, index) {
                              final item = _tocItems[index];
                              return _buildTocItem(item);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),  // Opacity end
        ),  // Transform.translate end
      ),  // Align end
    ),  // Container end
  ),  // GestureDetector end
);  // Outer GestureDetector end
      },  // TweenAnimationBuilder builder end
    );  // TweenAnimationBuilder end
  }

  Widget _buildTocItem(TocItem item) {
    final indent = (item.level - 1) * 16.0;
    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    final color = colors[(item.level - 1) % colors.length];

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _jumpToHeading(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      'H${item.level}',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16 - (item.level - 1) * 1.0,
                      fontWeight: item.level == 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditPanel(SettingsProvider settings) {
    return TextField(
      controller: _textController,
      scrollController: _editScrollController,
      undoController: _undoController, // 启用撤回重做功能
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        fontSize: settings.fontSize,
        fontFamily: 'monospace',
        height: 1.6,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(16),
        hintText: '开始编写你的 Markdown 内容...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 计算当前checkbox索引（用于checkboxBuilder）
    int checkboxIndex = 0;
    
    return Markdown(
      controller: _previewScrollController,
      data: _textController.text,
      selectable: true,
      padding: const EdgeInsets.all(16),
      // checkbox构建器：实现可点击的任务列表
      checkboxBuilder: (bool value) {
        final currentIndex = checkboxIndex++;
        return Checkbox(
          value: value,
          onChanged: (newValue) {
            _toggleCheckbox(currentIndex, newValue ?? false);
            // 重置索引以便下次重建
            checkboxIndex = 0;
          },
          activeColor: Theme.of(context).colorScheme.primary,
        );
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: settings.fontSize, height: 1.6),
        h1: TextStyle(
          fontSize: settings.fontSize * 2,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h2: TextStyle(
          fontSize: settings.fontSize * 1.5,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h3: TextStyle(
          fontSize: settings.fontSize * 1.25,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h4: TextStyle(
          fontSize: settings.fontSize * 1.1,
          fontWeight: FontWeight.w600,
        ),
        h5: TextStyle(
          fontSize: settings.fontSize,
          fontWeight: FontWeight.w600,
        ),
        h6: TextStyle(
          fontSize: settings.fontSize * 0.9,
          fontWeight: FontWeight.w600,
        ),
        code: TextStyle(
          backgroundColor: isDark 
              ? const Color(0xFF2d2d2d) 
              : const Color(0xFFf5f5f5),
          fontFamily: 'monospace',
          fontSize: settings.fontSize * 0.9,
          color: isDark ? const Color(0xFFe6e6e6) : const Color(0xFF333333),
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1e1e1e) 
              : const Color(0xFFf8f8f8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark 
                ? const Color(0xFF3d3d3d) 
                : const Color(0xFFe0e0e0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        codeblockPadding: const EdgeInsets.all(16),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
          ),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        listBullet: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: settings.fontSize,
        ),
        tableBody: TextStyle(fontSize: settings.fontSize),
        tableBorder: TableBorder.all(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(8),
        ),
        tableCellsPadding: const EdgeInsets.all(8),
        tableHeadAlign: TextAlign.center,
      ),
    );
  }
}

/// Table of contents item
class TocItem {
  final int level;
  final String title;
  final int lineNumber;

  TocItem({
    required this.level,
    required this.title,
    required this.lineNumber,
  });
}

/// 全屏预览页面
/// 支持返回手势和返回键退出
class _FullscreenPreviewPage extends StatelessWidget {
  final String markdownContent;
  final SettingsProvider settings;
  final String fileName;

  const _FullscreenPreviewPage({
    required this.markdownContent,
    required this.settings,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
            ),
            child: Icon(
              Icons.fullscreen_exit,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
      ),
      body: Markdown(
        data: markdownContent,
        selectable: true,
        padding: const EdgeInsets.all(20),
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(fontSize: settings.fontSize, height: 1.6),
          h1: TextStyle(
            fontSize: settings.fontSize * 2,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          h2: TextStyle(
            fontSize: settings.fontSize * 1.5,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          h3: TextStyle(
            fontSize: settings.fontSize * 1.25,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          h4: TextStyle(
            fontSize: settings.fontSize * 1.1,
            fontWeight: FontWeight.w600,
          ),
          h5: TextStyle(
            fontSize: settings.fontSize,
            fontWeight: FontWeight.w600,
          ),
          h6: TextStyle(
            fontSize: settings.fontSize * 0.9,
            fontWeight: FontWeight.w600,
          ),
          code: TextStyle(
            backgroundColor: isDark 
                ? const Color(0xFF2d2d2d) 
                : const Color(0xFFf5f5f5),
            fontFamily: 'monospace',
            fontSize: settings.fontSize * 0.9,
            color: isDark ? const Color(0xFFe6e6e6) : const Color(0xFF333333),
          ),
          codeblockDecoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1e1e1e) 
                : const Color(0xFFf8f8f8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark 
                  ? const Color(0xFF3d3d3d) 
                  : const Color(0xFFe0e0e0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          codeblockPadding: const EdgeInsets.all(16),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          listBullet: TextStyle(
            color: Theme.of(context).colorScheme.primary,
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          tableHead: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: settings.fontSize,
          ),
          tableBody: TextStyle(fontSize: settings.fontSize),
          tableBorder: TableBorder.all(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(8),
          ),
          tableCellsPadding: const EdgeInsets.all(8),
          tableHeadAlign: TextAlign.center,
        ),
      ),
    );
  }
}
