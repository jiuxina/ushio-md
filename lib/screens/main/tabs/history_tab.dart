// ============================================================================
// 历史记录标签页
//
// 合并最近文件和最近文件夹到一个标签页，
// 右上角提供切换按钮在文件/文件夹视图之间切换。
// 支持搜索、排序、拖拽排序等功能。
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/file_provider.dart';
import '../../../widgets/empty_state.dart';
import '../../../utils/app_style.dart';
import '../../../utils/capsule_nav_insets.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/sliding_segment_toggle.dart';

import '../../../utils/file_actions.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/responsive_page_frame.dart';
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
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    return ResponsivePageFrame(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 20,
        0,
        isDesktop ? 32 : 20,
        0,
      ),
      child: SizedBox(
        height: isDesktop ? null : 56,
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              color: context.appIconColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.historyTab,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // 清空历史按钮
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.clearHistory,
              style: IconButton.styleFrom(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              onPressed: _showClearHistoryDialog,
            ),
            const SizedBox(width: 8),
            _buildToggleButton(),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistoryConfirm),
        content: Text(
          l10n.clearHistoryConfirmMessage(
            _viewMode == HistoryViewMode.files ? l10n.file : l10n.folder,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
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
            child: Text(l10n.clear, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    final l10n = AppLocalizations.of(context)!;
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return AppSurface(
      borderRadius: BorderRadius.circular(12),
      color: appStyle.scaledSurfaceColor(
        Theme.of(context).colorScheme,
        alpha: 0.8,
      ),
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
      child: SlidingSegmentToggle(
        height: 36,
        selectedIndex: _viewMode == HistoryViewMode.files ? 0 : 1,
        onChanged: (index) => setState(() {
          _viewMode =
              index == 0 ? HistoryViewMode.files : HistoryViewMode.folders;
        }),
        items: [
          SlidingSegmentItem(icon: Icons.description, label: l10n.file),
          SlidingSegmentItem(icon: Icons.folder, label: l10n.folder),
        ],
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
    final l10n = AppLocalizations.of(context)!;
    final recentFiles = widget.fileProvider.recentFiles;
    final processedFiles = _processList(recentFiles);

    if (processedFiles.isEmpty) {
      return EmptyState(
        message: l10n.noRecentFiles,
        icon: Icons.description_outlined,
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: capsuleTabBarBottomInset(context)),
      children: [
        ResponsivePageFrame(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.isDesktopWidth(context) ? 32 : 20,
            ResponsiveLayout.isDesktopWidth(context) ? 24 : 12,
            ResponsiveLayout.isDesktopWidth(context) ? 32 : 20,
            20,
          ),
          child: Column(
            children: [
              for (final path in processedFiles)
                FileTile(
                  key: ValueKey(path),
                  entity: File(path),
                  source: FileSource.history,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoldersView() {
    final l10n = AppLocalizations.of(context)!;
    final recentFolders = widget.fileProvider.recentFolders;
    final processedFolders = _processList(recentFolders);

    if (processedFolders.isEmpty) {
      return EmptyState(message: l10n.noRecentFolders, icon: Icons.folder_open);
    }

    return ListView(
      padding: EdgeInsets.only(bottom: capsuleTabBarBottomInset(context)),
      children: [
        ResponsivePageFrame(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.isDesktopWidth(context) ? 32 : 20,
            ResponsiveLayout.isDesktopWidth(context) ? 24 : 12,
            ResponsiveLayout.isDesktopWidth(context) ? 32 : 20,
            20,
          ),
          child: Column(
            children: [
              for (final path in processedFolders)
                FileTile(
                  key: ValueKey(path),
                  entity: Directory(path),
                  source: FileSource.history,
                ),
            ],
          ),
        ),
      ],
    );
  }
} // End of HistoryTab State
