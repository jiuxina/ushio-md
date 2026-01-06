import 'package:flutter/material.dart';
import '../../../models/file_sort_option.dart';

class FolderBrowserHeader extends StatelessWidget {
  final String folderName;
  final int fileCount;
  final bool isSearching;
  final VoidCallback onSearchToggle;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final FileSortOption sortOption;
  final ValueChanged<FileSortOption> onSortChanged;
  final VoidCallback? onBack;

  final bool showImages;
  final VoidCallback onImageToggle;
  final VoidCallback onNewItem;

  const FolderBrowserHeader({
    super.key,
    required this.folderName,
    required this.fileCount,
    required this.isSearching,
    required this.onSearchToggle,
    required this.searchController,
    required this.onSearchChanged,
    required this.sortOption,
    required this.onSortChanged,
    required this.onBack,
    required this.showImages,
    required this.onImageToggle,
    required this.onNewItem,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return _buildSearchHeader(context);
    }
    return _buildHeader(context);
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              onPressed: onBack,
            )
          else
            const SizedBox(width: 8),
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
                  '$fileCount 个文件',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          _buildIconButton(
            context,
            icon: Icons.search,
            onPressed: onSearchToggle,
          ),
          const SizedBox(width: 4),
          _buildIconButton(
            context,
            icon: showImages ? Icons.image : Icons.image_outlined,
            onPressed: onImageToggle,
            isActive: showImages,
          ),
          const SizedBox(width: 4),
          _buildSortButton(context),
          const SizedBox(width: 4),
          _buildIconButton(
            context,
            icon: Icons.add,
            onPressed: onNewItem,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          _buildIconButton(
            context,
            icon: Icons.arrow_back,
            onPressed: onSearchToggle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文件...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, {
    required IconData icon, 
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive 
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive 
                  ? colorScheme.primary 
                  : Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            icon, 
            size: 20, 
            color: isActive ? colorScheme.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSortMenu(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: const Icon(Icons.sort, size: 20),
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
              Text(
                '排序方式',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              _buildSortOption(context, FileSortOption.custom, '自定义排序', Icons.drag_indicator),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildSortOption(context, FileSortOption.nameAsc, '名称 A-Z', Icons.sort_by_alpha),
              const SizedBox(height: 8),
              _buildSortOption(context, FileSortOption.nameDesc, '名称 Z-A', Icons.sort_by_alpha),
              const SizedBox(height: 16),
              _buildSortOption(context, FileSortOption.dateDesc, '最近修改', Icons.access_time),
              const SizedBox(height: 8),
              _buildSortOption(context, FileSortOption.dateAsc, '最早修改', Icons.history),
              const SizedBox(height: 16),
              _buildSortOption(context, FileSortOption.sizeDesc, '最大优先', Icons.expand),
              const SizedBox(height: 8),
              _buildSortOption(context, FileSortOption.sizeAsc, '最小优先', Icons.compress),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, FileSortOption option, String label, IconData icon) {
    final isSelected = sortOption == option;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          onSortChanged(option);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
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
}
