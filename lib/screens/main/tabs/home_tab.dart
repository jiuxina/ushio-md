import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../providers/file_provider.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/file_actions.dart';

// HomeTab calls QuickActions. QuickActions uses FileImportHelper. But HomeTab itself doesn't.
// But QuickActions is imported.
import '../../../widgets/app_background.dart';
import '../components/quick_actions.dart';
import '../../folder/components/file_tile.dart';

class HomeTab extends StatefulWidget {
  final FileProvider fileProvider;

  const HomeTab({super.key, required this.fileProvider});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          _buildHomeHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => widget.fileProvider.refresh(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  QuickActions(fileProvider: widget.fileProvider),
                  
                  // Pinned files section
                  if (widget.fileProvider.pinnedFiles.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('置顶文件', Icons.push_pin),
                    const SizedBox(height: 12),
                    _buildPinnedFilesList(),
                  ],
                  
                  // Pinned folders section
                  if (widget.fileProvider.pinnedFolders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('置顶文件夹', Icons.folder_special),
                    const SizedBox(height: 12),
                    _buildPinnedFoldersList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'app.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                AppConstants.appDescription,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildPinnedFilesList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.fileProvider.pinnedFiles.length,
      onReorder: widget.fileProvider.reorderPinnedFiles,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = 1.0 + (animation.value * 0.05);
            return Transform.scale(scale: scale, child: child);
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final path = widget.fileProvider.pinnedFiles[index];
        return FileTile(
          key: ValueKey(path),
          entity: File(path),
          index: index,
          isDraggable: true,
          source: FileSource.pinned,
        );
      },
    );
  }

  Widget _buildPinnedFoldersList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.fileProvider.pinnedFolders.length,
      onReorder: widget.fileProvider.reorderPinnedFolders,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = 1.0 + (animation.value * 0.05);
            return Transform.scale(scale: scale, child: child);
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final path = widget.fileProvider.pinnedFolders[index];
        return FileTile(
          key: ValueKey(path),
          entity: Directory(path),
          index: index,
          isDraggable: true,
          source: FileSource.pinned,
        );
      },
    );
  }
} // End of State class

