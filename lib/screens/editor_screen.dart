import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/markdown_toolbar.dart';
import '../widgets/markdown_preview.dart';
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
  late ScrollController _previewScrollController;
  late UndoHistoryController _undoController;

  EditorMode _mode = EditorMode.preview;
  bool _isLoading = true;
  bool _isModified = false;
  bool _isSaving = false;
  bool _showToc = false;
  Timer? _autoSaveTimer;
  Timer? _tocDebounceTimer;
  // ==================== 正则表达式缓存 ====================
  static final _headingRegex = RegExp(r'^(#{1,6})\s*(.+)$');
  static final _h1UnderlineRegex = RegExp(r'^=+$');
  static final _h2UnderlineRegex = RegExp(r'^-+$');
  static final _uncheckedBoxRegex = RegExp(r'^(\s*-\s*)\[\s*\](.*)$');
  static final _checkedBoxRegex = RegExp(r'^(\s*-\s*)\[[xX]\](.*)$');
  static final _wordSplitRegex = RegExp(r'\s+');

  String? _error;
  List<TocItem> _tocItems = [];

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editScrollController = ScrollController();
    _previewScrollController = ScrollController();
    _undoController = UndoHistoryController();
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
           ));
         } else if (_h2UnderlineRegex.hasMatch(nextLine)) {
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
    setState(() => _showToc = false);

    final lines = _textController.text.split('\n');
    int position = 0;
    for (int i = 0; i < item.lineNumber && i < lines.length; i++) {
      position += lines[i].length + 1;
    }
    final totalLength = _textController.text.length;
    final ratio = totalLength > 0 ? position / totalLength : 0.0;

    if (_mode == EditorMode.edit) {
      _textController.selection = TextSelection.collapsed(offset: position);
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
    _previewScrollController.dispose();
    _undoController.dispose();
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
          setState(() => _mode = EditorMode.edit);
          
          Future.delayed(const Duration(milliseconds: 100), () {
            _textController.selection = TextSelection(
              baseOffset: position,
              extentOffset: position + length,
            );
            
            if (_editScrollController.hasClients) {
              final lines = _textController.text.substring(0, position).split('\n');
              final lineHeight = 24.0; 
              final targetScroll = lines.length * lineHeight;
              _editScrollController.animateTo(
                targetScroll.clamp(0.0, _editScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
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
  /// [index] 复选框在文档中的索引（第几个复选框）
  /// [newValue] 新的选中状态
  void _toggleCheckbox(int index, bool newValue) {
    final text = _textController.text;
    final lines = text.split('\n');
    int checkboxCount = 0;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final uncheckedMatch = _uncheckedBoxRegex.firstMatch(line);
      final checkedMatch = _checkedBoxRegex.firstMatch(line);
      
      if (uncheckedMatch != null || checkedMatch != null) {
        if (checkboxCount == index) {
          if (newValue) {
            if (uncheckedMatch != null) {
              lines[i] = '${uncheckedMatch.group(1)}[x]${uncheckedMatch.group(2)}';
            }
          } else {
            if (checkedMatch != null) {
              lines[i] = '${checkedMatch.group(1)}[ ]${checkedMatch.group(2)}';
            }
          }
          break;
        }
        checkboxCount++;
      }
    }
    
    final newText = lines.join('\n');
    if (newText != text) {
      setState(() {
        _textController.text = newText;
        _isModified = true;
      });
    }
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
        resizeToAvoidBottomInset: false,
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

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
            Positioned(
              right: 24,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingButton(Icons.search, Colors.teal, _showSearchDialog),
                  const SizedBox(height: 12),
                  _buildFloatingButton(Icons.fullscreen, Theme.of(context).colorScheme.secondary, _openFullscreenPreview),
                  const SizedBox(height: 12),
                  _buildFloatingButton(Icons.list, Theme.of(context).colorScheme.primary, () => setState(() => _showToc = true)),
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
    return TextField(
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
    );
  }

  Widget _buildPreviewPanel(SettingsProvider settings) {
    return MarkdownPreview(
      data: _textController.text,
      settings: settings,
      controller: _previewScrollController,
      onCheckboxChanged: _toggleCheckbox,
      baseDirectory: File(widget.filePath).parent.path,
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
