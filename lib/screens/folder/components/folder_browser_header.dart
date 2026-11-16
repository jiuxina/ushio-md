import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/file_sort_option.dart';
import '../../../utils/app_style.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/glass_header_button.dart';

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
  final bool isSelecting;
  final bool isBusy;
  final int selectedCount;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onSelectAll;
  final VoidCallback? onInvertSelection;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onMoveSelected;

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
    this.isSelecting = false,
    this.isBusy = false,
    this.selectedCount = 0,
    this.onSelectionToggle,
    this.onSelectAll,
    this.onInvertSelection,
    this.onDeleteSelected,
    this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelecting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectionHeader(context),
          if (isSearching) _buildSearchHeader(context),
        ],
      );
    }
    if (isSearching) {
      return _buildSearchHeader(context);
    }
    return _buildHeader(context);
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    return SizedBox(
      height: isDesktop ? null : 56,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
        child: Row(
          children: [
            if (onBack != null)
              GlassHeaderButton(
                icon: Icons.arrow_back,
                onPressed: onBack,
                iconColor: Theme.of(context).colorScheme.primary,
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
                    l10n.fileCount(fileCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            GlassHeaderButton(icon: Icons.search, onPressed: onSearchToggle),
            const SizedBox(width: 4),
            if (onSelectionToggle != null) ...[
              GlassHeaderButton(
                key: const ValueKey('select-items'),
                icon: Icons.checklist,
                tooltip: l10n.selectItems,
                onPressed: onSelectionToggle,
              ),
              const SizedBox(width: 4),
            ],
            GlassHeaderButton(
              icon: showImages ? Icons.image : Icons.image_outlined,
              onPressed: onImageToggle,
              isActive: showImages,
            ),
            const SizedBox(width: 4),
            GlassHeaderButton(
              icon: Icons.sort,
              onPressed: () => _showSortMenu(context),
            ),
            const SizedBox(width: 4),
            GlassHeaderButton(icon: Icons.add, onPressed: onNewItem),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('cancel-selection'),
                tooltip: l10n.cancel,
                onPressed: isBusy ? null : onSelectionToggle,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  l10n.selectedItemCount(selectedCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  key: const ValueKey('selection-search'),
                  tooltip: l10n.searchFiles,
                  onPressed: onSearchToggle,
                  icon: const Icon(Icons.search),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                key: const ValueKey('select-all-items'),
                tooltip: l10n.selectAllItems,
                onPressed: isBusy ? null : onSelectAll,
                icon: const Icon(Icons.select_all),
              ),
              IconButton(
                key: const ValueKey('invert-selection'),
                tooltip: l10n.invertSelection,
                onPressed: isBusy ? null : onInvertSelection,
                icon: const Icon(Icons.flip_to_back),
              ),
              IconButton(
                key: const ValueKey('move-selected-items'),
                tooltip: l10n.moveSelectedItems,
                onPressed: isBusy || selectedCount == 0 ? null : onMoveSelected,
                icon: const Icon(Icons.drive_file_move_outline),
              ),
              IconButton(
                key: const ValueKey('delete-selected-items'),
                tooltip: l10n.deleteSelectedItems,
                onPressed: isBusy || selectedCount == 0
                    ? null
                    : onDeleteSelected,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = ResponsiveLayout.isDesktopWidth(context);
    return SizedBox(
      height: isDesktop ? null : 56,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
        child: Row(
          children: [
            GlassHeaderButton(
              icon: Icons.arrow_back,
              onPressed: onSearchToggle,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppSurface(
                borderRadius: BorderRadius.circular(12),
                height: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: appStyle.scaledSurfaceColor(colorScheme, alpha: 0.5),
                prominent: appStyle.useBorderlessButtons,
                border: appStyle.useBorderlessButtons
                    ? null
                    : Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.5),
                      ),
                child: TextField(
                  enabled: !isBusy,
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchFiles,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: colorScheme.outline,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.sortBy,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildSortOption(
                context,
                FileSortOption.custom,
                l10n.customSort,
                Icons.drag_indicator,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildSortOption(
                context,
                FileSortOption.nameAsc,
                l10n.nameAZ,
                Icons.sort_by_alpha,
              ),
              const SizedBox(height: 8),
              _buildSortOption(
                context,
                FileSortOption.nameDesc,
                l10n.nameZA,
                Icons.sort_by_alpha,
              ),
              const SizedBox(height: 16),
              _buildSortOption(
                context,
                FileSortOption.dateDesc,
                l10n.recentModified,
                Icons.access_time,
              ),
              const SizedBox(height: 8),
              _buildSortOption(
                context,
                FileSortOption.dateAsc,
                l10n.oldestModified,
                Icons.history,
              ),
              const SizedBox(height: 16),
              _buildSortOption(
                context,
                FileSortOption.sizeDesc,
                l10n.largestFirst,
                Icons.expand,
              ),
              const SizedBox(height: 8),
              _buildSortOption(
                context,
                FileSortOption.sizeAsc,
                l10n.smallestFirst,
                Icons.compress,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    FileSortOption option,
    String label,
    IconData icon,
  ) {
    final isSelected = sortOption == option;
    final iconColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : context.appIconColor;
    final textColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;

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
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
