import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../models/markdown_file.dart';
import 'editor_screen.dart';

/// Sort options for files
enum FileSortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
}

class FolderBrowserScreen extends StatefulWidget {
  final String folderPath;

  const FolderBrowserScreen({super.key, required this.folderPath});

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoading = true;
  List<MarkdownFile> _files = [];
  String? _error;
  FileSortOption _sortOption = FileSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fileProvider = context.read<FileProvider>();
      _files = await fileProvider.fileService.listMarkdownFiles(widget.folderPath);
      _sortFiles();
    } catch (e) {
      _error = e.toString();
      _files = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _sortFiles() {
    switch (_sortOption) {
      case FileSortOption.nameAsc:
        _files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FileSortOption.nameDesc:
        _files.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case FileSortOption.dateAsc:
        _files.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case FileSortOption.dateDesc:
        _files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case FileSortOption.sizeAsc:
        _files.sort((a, b) => a.size.compareTo(b.size));
        break;
      case FileSortOption.sizeDesc:
        _files.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    if (mounted) setState(() {});
  }

  List<MarkdownFile> get _filteredFiles {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _files;
    return _files.where((file) => 
      file.name.toLowerCase().contains(query) ||
      file.displayName.toLowerCase().contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderName = widget.folderPath.split(Platform.pathSeparator).last;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f23),
                  ]
                : [
                    const Color(0xFFf8f9ff),
                    const Color(0xFFf0f4ff),
                    const Color(0xFFe8eeff),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(folderName),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String folderName) {
    if (_isSearching) {
      return _buildSearchHeader();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folderName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_files.length} 个文件',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          _buildIconButton(
            icon: Icons.search,
            onPressed: () => setState(() => _isSearching = true),
          ),
          const SizedBox(width: 4),
          _buildSortButton(),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back,
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文件...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showSortMenu,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: const Icon(Icons.sort, size: 20),
        ),
      ),
    );
  }

  void _showSortMenu() {
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
              '排序方式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildSortOption(FileSortOption.nameAsc, '名称 A-Z', Icons.sort_by_alpha),
            const SizedBox(height: 8),
            _buildSortOption(FileSortOption.nameDesc, '名称 Z-A', Icons.sort_by_alpha),
            const SizedBox(height: 16),
            _buildSortOption(FileSortOption.dateDesc, '最近修改', Icons.access_time),
            const SizedBox(height: 8),
            _buildSortOption(FileSortOption.dateAsc, '最早修改', Icons.history),
            const SizedBox(height: 16),
            _buildSortOption(FileSortOption.sizeDesc, '最大优先', Icons.expand),
            const SizedBox(height: 8),
            _buildSortOption(FileSortOption.sizeAsc, '最小优先', Icons.compress),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(FileSortOption option, String label, IconData icon) {
    final isSelected = _sortOption == option;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          setState(() {
            _sortOption = option;
          });
          _sortFiles();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_files.isEmpty) {
      return _buildEmptyState('此文件夹没有 Markdown 文件');
    }

    final filteredFiles = _filteredFiles;
    if (filteredFiles.isEmpty) {
      return _buildEmptyState('没有找到匹配的文件');
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: filteredFiles.length,
        itemBuilder: (context, index) {
          return _buildFileTile(filteredFiles[index]);
        },
      ),
    );
  }

  Widget _buildFileTile(MarkdownFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final fileProvider = context.read<FileProvider>();
            fileProvider.addToRecentFiles(file.path);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditorScreen(filePath: file.path),
              ),
            );
          },
          onLongPress: () {
            final fileProvider = context.read<FileProvider>();
            _showFileContextMenu(file.path, fileProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.displayName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${file.formattedSize} · ${file.formattedDate}',
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
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示文件上下文菜单
  void _showFileContextMenu(String path, FileProvider fileProvider) {
    final fileName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFilePinned(path);
    
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
              fileName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildContextMenuItem(
              icon: Icons.open_in_new,
              label: '打开',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                fileProvider.addToRecentFiles(path);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditorScreen(filePath: path),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: isCurrentlyPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶到首页',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                fileProvider.togglePinFile(path);
              },
            ),
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: Icons.edit,
              label: '重命名',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(path, fileProvider);
              },
            ),
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: Icons.delete,
              label: '删除文件',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(path, fileProvider);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建上下文菜单项
  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示重命名对话框
  Future<void> _showRenameDialog(String path, FileProvider fileProvider) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.replaceAll('.md', '').replaceAll('.markdown', '');
    final controller = TextEditingController(text: nameWithoutExt);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('重命名文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '新文件名',
            suffixText: '.md',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != nameWithoutExt) {
      try {
        final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
        final newPath = '$dir${Platform.pathSeparator}$result.md';
        final file = File(path);
        await file.rename(newPath);
        
        // 刷新文件列表
        await _loadFiles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('重命名成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败: $e')),
          );
        }
      }
    }
    
    controller.dispose();
  }

  /// 确认删除对话框
  Future<void> _confirmDelete(String path, FileProvider fileProvider) async {
    final fileName = path.split(Platform.pathSeparator).last;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除文件'),
        content: Text('确定要删除 "$fileName" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await fileProvider.deleteFile(path);
      if (success) {
        // 刷新文件列表
        await _loadFiles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件已删除')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }
}
