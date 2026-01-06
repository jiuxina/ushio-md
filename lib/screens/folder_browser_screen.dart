import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/file_sort_option.dart';
import '../../services/folder_sort_service.dart';
import '../../utils/file_actions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/particle_effect_widget.dart';
import 'folder/components/folder_browser_header.dart';
import 'folder/components/file_tile.dart';

class FolderBrowserScreen extends StatefulWidget {
  final String folderPath;
  final bool showBackButton;
  final String? title;

  const FolderBrowserScreen({
    super.key, 
    required this.folderPath,
    this.showBackButton = true,
    this.title,
  });

  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FolderSortService _sortService = FolderSortService();
  
  bool _isSearching = false;
  bool _isLoading = true;
  bool _showImages = false; // 默认不显示图片
  
  List<FileSystemEntity> _entities = [];
  String? _error;
  FileSortOption _sortOption = FileSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }
  
  Future<void> _initAndLoad() async {
    await _sortService.init();
    if (mounted) {
      final index = _sortService.getSortOptionIndex(widget.folderPath);
      if (index >= 0 && index < FileSortOption.values.length) {
        _sortOption = FileSortOption.values[index];
      }
      _loadFiles();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dir = Directory(widget.folderPath);
      if (!await dir.exists()) {
        throw Exception('文件夹不存在');
      }

      final entities = await dir.list().toList();
      _entities = entities.where((e) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) return false; // 隐藏隐藏文件
        
        final isDir = e is Directory;
        if (isDir) return true;
        
        // 文件过滤
        if (name.toLowerCase().endsWith('.md')) return true;
        if (_showImages && _isImage(name)) return true;
        
        return false;
      }).toList();

      _sortFiles();
    } catch (e) {
      _error = e.toString();
      _entities = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') || 
           lower.endsWith('.jpeg') || 
           lower.endsWith('.png') || 
           lower.endsWith('.gif') || 
           lower.endsWith('.webp');
  }

  void _sortFiles() {
    if (_sortOption == FileSortOption.custom) {
      _entities = _sortService.sortEntities(widget.folderPath, _entities);
      if (mounted) setState(() {});
      return;
    }

    _entities.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      
      // 始终让文件夹排在前面 (除非自定义排序?) 
      // 通常文件管理器也是文件夹优先，这里保持一致
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      
      final nameA = a.path.split(Platform.pathSeparator).last;
      final nameB = b.path.split(Platform.pathSeparator).last;
      
      switch (_sortOption) {
        case FileSortOption.nameAsc:
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        case FileSortOption.nameDesc:
          return nameB.toLowerCase().compareTo(nameA.toLowerCase());
        case FileSortOption.dateAsc:
          return FileSystemEntity.isFileSync(a.path) && FileSystemEntity.isFileSync(b.path)
              ? File(a.path).lastModifiedSync().compareTo(File(b.path).lastModifiedSync())
              : 0; // Folder date sort might be inaccurate, keeping simple
        case FileSortOption.dateDesc:
          return FileSystemEntity.isFileSync(a.path) && FileSystemEntity.isFileSync(b.path)
            ? File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync())
            : 0;
        case FileSortOption.sizeAsc:
          return FileSystemEntity.isFileSync(a.path) && FileSystemEntity.isFileSync(b.path)
            ? File(a.path).lengthSync().compareTo(File(b.path).lengthSync())
            : 0;
        case FileSortOption.sizeDesc:
          return FileSystemEntity.isFileSync(a.path) && FileSystemEntity.isFileSync(b.path)
            ? File(b.path).lengthSync().compareTo(File(a.path).lengthSync())
            : 0;
        default:
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      }
    });
    
    if (mounted) setState(() {});
  }
  
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    // 如果当前不是自定义排序，拖拽后自动切换为自定义排序
    if (_sortOption != FileSortOption.custom) {
      setState(() {
        _sortOption = FileSortOption.custom;
      });
      await _sortService.saveSortOption(widget.folderPath, FileSortOption.custom.index);
    }
    
    setState(() {
      final item = _entities.removeAt(oldIndex);
      _entities.insert(newIndex, item);
    });
    
    // 保存新顺序
    final filenames = _entities.map((e) => e.path.split(Platform.pathSeparator).last).toList();
    await _sortService.saveOrder(widget.folderPath, filenames);
  }

  List<FileSystemEntity> get _filteredFiles {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _entities;
    return _entities.where((e) {
      final name = e.path.split(Platform.pathSeparator).last.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  void _showNewItemMenu() {
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
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.blue),
              title: const Text('新建 Markdown'),
              onTap: () {
                Navigator.pop(context);
                FileActions.showCreateFileInFolderDialog(context, widget.folderPath, context.read<FileProvider>());
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.orange),
              title: const Text('新建文件夹'),
              onTap: () {
                Navigator.pop(context);
                _showCreateFolderDialog();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCreateFolderDialog() {
    // 简化的新建文件夹 Dialog，直接在当前目录
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: '文件夹名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (nameController.text.isNotEmpty) {
                try {
                  final newPath = '${widget.folderPath}${Platform.pathSeparator}${nameController.text}';
                  await Directory(newPath).create();
                  _loadFiles();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
                }
              }
            }, 
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final folderName = widget.folderPath.split(Platform.pathSeparator).last;
    
    // Title Override Logic
    String displayName;
    if (widget.title != null) {
      displayName = widget.title!;
    } else if (folderName == 'Ushio-MD') {
      displayName = '我的文件';
    } else {
      displayName = folderName;
    }

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        BoxDecoration backgroundDecoration;
        if (settings.backgroundImagePath != null && File(settings.backgroundImagePath!).existsSync()) {
          backgroundDecoration = BoxDecoration(
            image: DecorationImage(
              image: FileImage(File(settings.backgroundImagePath!)),
              fit: BoxFit.cover,
            ),
          );
        } else {
          backgroundDecoration = BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f0f23)]
                  : [const Color(0xFFf8f9ff), const Color(0xFFf0f4ff), const Color(0xFFe8eeff)],
            ),
          );
        }

        return Scaffold(
          body: Container(
            decoration: backgroundDecoration,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: settings.backgroundEffect == 'blur' ? settings.backgroundBlur : 0,
                sigmaY: settings.backgroundEffect == 'blur' ? settings.backgroundBlur : 0,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        FolderBrowserHeader(
                          folderName: displayName,
                          fileCount: _entities.length,
                          isSearching: _isSearching,
                          onSearchToggle: () {
                            setState(() {
                              if (_isSearching) {
                                _isSearching = false;
                                _searchController.clear();
                              } else {
                                _isSearching = true;
                              }
                            });
                          },
                          searchController: _searchController,
                          onSearchChanged: (value) => setState(() {}),
                          sortOption: _sortOption,
                          onSortChanged: (option) async {
                            setState(() => _sortOption = option);
                            await _sortService.saveSortOption(widget.folderPath, option.index);
                            _sortFiles();
                          },
                          onBack: widget.showBackButton ? () => Navigator.pop(context) : null,
                          showImages: _showImages,
                          onImageToggle: () {
                            setState(() => _showImages = !_showImages);
                            _loadFiles(); // 重新加载以过滤/显示图片
                          },
                          onNewItem: _showNewItemMenu,
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
            ),
          ),
        );
      }
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('加载失败: $_error', style: const TextStyle(color: Colors.red)));
    }

    if (_entities.isEmpty) {
      return const EmptyState(message: '此文件夹为空');
    }

    final filtered = _filteredFiles;
    if (filtered.isEmpty) {
      return const EmptyState(message: '没有找到匹配的文件');
    }

    // 始终使用 ReorderableListView 以支持拖拽排序 (如果处于非自定义排序，拖拽后会自动切换到自定义)
    // 只有在搜索时禁用拖拽(? 搜索结果通常不建议拖拽排序，因为索引不对应)
    if (_isSearching && _searchController.text.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return FileTile(
              entity: filtered[index],
              onRefresh: _loadFiles,
              isDraggable: false,
              source: FileSource.myFiles,
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: filtered.length,
        buildDefaultDragHandles: false, // 禁用默认的长按拖拽，使用 FileTile 内部的 Handle
        onReorder: _handleReorder,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double animValue = Curves.easeInOut.transform(animation.value);
              final double scale = lerpDouble(1.0, 1.05, animValue)!;
              return Transform.scale(
                scale: scale,
                child: Material(
                  elevation: 8,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final entity = filtered[index];
          return Container(
            key: ValueKey(entity.path),
            child: FileTile(
              entity: entity,
              onRefresh: _loadFiles,
              isDraggable: true, // 总是显示拖拽手柄
              index: index, // 传递 index 给 ReorderableDragStartListener
              source: FileSource.myFiles,
            ),
          );
        },
      ),
    );
  }
}
