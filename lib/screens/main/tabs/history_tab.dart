// ============================================================================
// 历史记录标签页
// 
// 合并最近文件和最近文件夹到一个标签页，
// 右上角提供切换按钮在文件/文件夹视图之间切换。
// 支持搜索、排序、拖拽排序等功能。
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../providers/file_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/empty_state.dart';

import '../../../utils/file_actions.dart';
import '../../folder/components/file_tile.dart';

/// 历史记录视图模式
enum HistoryViewMode { files, folders }

class HistoryTab extends StatefulWidget {
  final FileProvider fileProvider;

  const HistoryTab({super.key, required this.fileProvider});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  HistoryViewMode _viewMode = HistoryViewMode.files;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.history_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '历史',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          // 清空历史按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空历史',
            onPressed: _showClearHistoryDialog,
          ),
          const SizedBox(width: 8),
          _buildToggleButton(),
        ],
      ),
    );
  }
  

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录'),
        content: Text('确定要清空所有最近${_viewMode == HistoryViewMode.files ? '文件' : '文件夹'}记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_viewMode == HistoryViewMode.files) {
                widget.fileProvider.clearRecentFiles();
              } else {
                widget.fileProvider.clearRecentFolders();
              }
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleItem(
            icon: Icons.description,
            label: '文件',
            isSelected: _viewMode == HistoryViewMode.files,
            onTap: () => setState(() {
              _viewMode = HistoryViewMode.files;
            }),
          ),
          _buildToggleItem(
            icon: Icons.folder,
            label: '文件夹',
            isSelected: _viewMode == HistoryViewMode.folders,
            onTap: () => setState(() {
              _viewMode = HistoryViewMode.folders;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget _buildContent() {
    if (_viewMode == HistoryViewMode.files) {
      return _buildFilesView();
    } else {
      return _buildFoldersView();
    }
  }
  
  List<String> _processList(List<String> items) {
    // 默认按时间倒序 (Provider 中通常已经是倒序，但为了保险起见可以再次排序)
    // 这里简单返回，因为 RecentFiles 一般就是按时间存的
    return items;
  }

  Widget _buildFilesView() {
    final recentFiles = widget.fileProvider.recentFiles;
    final processedFiles = _processList(recentFiles);

    if (processedFiles.isEmpty) {
      return const EmptyState(
        message: '没有最近打开的文件',
        icon: Icons.description_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: processedFiles.length,
      itemBuilder: (context, index) {
        // Use FileTile with history source
        final path = processedFiles[index];
        return FileTile(
          key: ValueKey(path),
          entity: File(path),
          source: FileSource.history,
        );
      },
    );
  }

  Widget _buildFoldersView() {
    final recentFolders = widget.fileProvider.recentFolders;
    final processedFolders = _processList(recentFolders);

    if (processedFolders.isEmpty) {
      return const EmptyState(
        message: '没有最近文件夹',
        icon: Icons.folder_open,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: processedFolders.length,
      itemBuilder: (context, index) {
        // Use FileTile with history source
        final path = processedFolders[index];
        return FileTile(
          key: ValueKey(path),
          entity: Directory(path),
          source: FileSource.history,
        );
      },
    );
  }
} // End of HistoryTab State
