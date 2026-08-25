import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/file_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../utils/file_actions.dart';
import '../../../../utils/app_style.dart';
import '../../../../utils/capsule_nav_insets.dart';

import '../../../utils/responsive_layout.dart';
import '../../../widgets/responsive_page_frame.dart';
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
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHomeHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => widget.fileProvider.refresh(),
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: capsuleTabBarBottomInset(context),
                ),
                children: [
                  ResponsivePageFrame(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuickActions(
                          fileProvider: widget.fileProvider,
                          onRefresh: () => widget.fileProvider.refresh(),
                        ),
                        if (widget.fileProvider.pinnedFiles.isNotEmpty) ...[
                          SizedBox(height: isDesktop ? 20 : 24),
                          _buildSectionHeader('置顶文件', Icons.push_pin),
                          const SizedBox(height: 12),
                          _buildPinnedFilesList(),
                        ],
                        if (widget.fileProvider.pinnedFolders.isNotEmpty) ...[
                          SizedBox(height: isDesktop ? 20 : 24),
                          _buildSectionHeader('置顶文件夹', Icons.folder_special),
                          const SizedBox(height: 12),
                          _buildPinnedFoldersList(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHeader() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final iconMode = settings.homeIconMode;
        final customPath = settings.homeIconCustomPath;

        // 决定图标 widget，'none' 时不显示
        Widget? iconWidget;
        if (iconMode != 'none') {
          ImageProvider? imageProvider;
          if (iconMode == 'icon2') {
            imageProvider = const AssetImage('assets/icons/icon2.png');
          } else if (iconMode == 'custom' && customPath != null) {
            imageProvider = FileImage(File(customPath));
          } else {
            // default
            imageProvider = const AssetImage('app.png');
          }

          iconWidget = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.image_not_supported,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
          );
        }

        final isDesktop = ResponsiveLayout.isDesktopWidth(context);
        return ResponsivePageFrame(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 20,
            isDesktop ? 20 : 16,
            isDesktop ? 32 : 20,
            8,
          ),
          child: Row(
            children: [
              if (iconWidget != null) ...[
                iconWidget,
                const SizedBox(width: 12),
              ],
              Text(
                settings.homeTitleText,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.appMutedIconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
