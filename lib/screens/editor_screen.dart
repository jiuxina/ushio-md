import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

  EditorMode _mode = EditorMode.edit;
  bool _isLoading = true;
  bool _isModified = false;
  bool _isSaving = false;
  bool _showToc = false;
  Timer? _autoSaveTimer;
  String? _error;
  List<TocItem> _tocItems = [];

  String get fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editScrollController = ScrollController();
    _previewScrollController = ScrollController();
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
    _updateToc();
  }

  void _updateToc() {
    final lines = _textController.text.split('\n');
    final items = <TocItem>[];
    int lineNumber = 0;

    for (final line in lines) {
      if (line.startsWith('#')) {
        final match = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
        if (match != null) {
          final level = match.group(1)!.length;
          final title = match.group(2)!;
          items.add(TocItem(
            level: level,
            title: title,
            lineNumber: lineNumber,
          ));
        }
      }
      lineNumber++;
    }

    setState(() => _tocItems = items);
  }

  void _jumpToHeading(TocItem item) {
    // Close TOC first
    setState(() => _showToc = false);

    // Calculate approximate scroll position based on heading index
    // We estimate based on the position of this heading among all headings
    final headingIndex = _tocItems.indexOf(item);
    final totalHeadings = _tocItems.length;
    
    if (_mode == EditorMode.edit) {
      // In edit mode, move cursor to line
      final lines = _textController.text.split('\n');
      int position = 0;
      for (int i = 0; i < item.lineNumber && i < lines.length; i++) {
        position += lines[i].length + 1;
      }
      _textController.selection = TextSelection.collapsed(offset: position);
      
      // Scroll edit panel
      if (_editScrollController.hasClients) {
        final maxScroll = _editScrollController.position.maxScrollExtent;
        final targetScroll = (item.lineNumber / lines.length) * maxScroll;
        _editScrollController.animateTo(
          targetScroll.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // In preview or split mode, scroll preview panel
      if (_previewScrollController.hasClients) {
        final maxScroll = _previewScrollController.position.maxScrollExtent;
        // Calculate position based on heading index ratio
        final targetScroll = totalHeadings > 1
            ? (headingIndex / (totalHeadings - 1)) * maxScroll
            : 0.0;
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
    _textController.dispose();
    _editScrollController.dispose();
    _previewScrollController.dispose();
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
              MarkdownToolbar(controller: _textController),
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
          _buildModeButton(EditorMode.edit, '编辑', Icons.edit),
          _buildModeButton(EditorMode.split, '分屏', Icons.vertical_split),
          _buildModeButton(EditorMode.preview, '预览', Icons.visibility),
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
            // TOC button
            if (_tocItems.isNotEmpty)
              Positioned(
                right: 24,
                bottom: 24,
                child: _buildTocButton(),
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
                child: Stack(
                  children: [
                    Container(
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
                    // TOC button
                    if (_tocItems.isNotEmpty)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _buildTocButton(mini: true),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
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
    return GestureDetector(
      onTap: () => setState(() => _showToc = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Align(
          alignment: Alignment.centerRight,
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
          ),
        ),
      ),
    );
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
    
    return Markdown(
      controller: _previewScrollController,
      data: _textController.text,
      selectable: true,
      padding: const EdgeInsets.all(16),
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
