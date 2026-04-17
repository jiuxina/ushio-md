/// Inline search widget for the editor.
///
/// Provides a search bar with match navigation and candidate list.
library;

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/app_style.dart';
import '../models/editor_models.dart';

/// A callback for jumping to a search match.
typedef JumpToMatchCallback = void Function(SearchMatch match);

/// A widget that displays an inline search bar for the editor.
class EditorSearchBar extends StatefulWidget {
  /// The text controller for the search input.
  final TextEditingController controller;

  /// The focus node for the search input.
  final FocusNode focusNode;

  /// Current search matches.
  final List<SearchMatch> matches;

  /// Index of the currently active match.
  final int activeMatchIndex;

  /// Callback when search query changes.
  final ValueChanged<String> onSearch;

  /// Callback to jump to a specific match.
  final JumpToMatchCallback onJumpToMatch;

  /// Callback to jump to next match.
  final VoidCallback onJumpToNext;

  /// Callback to jump to previous match.
  final VoidCallback onJumpToPrevious;

  /// Callback when search is closed.
  final VoidCallback onClose;

  /// Whether to show the candidates dropdown.
  final bool showCandidates;

  /// Current search options.
  final SearchOptions searchOptions;

  /// Callback when search options change.
  final ValueChanged<SearchOptions> onOptionsChanged;

  /// Search history items.
  final List<String> searchHistory;

  /// Callback when a history item is selected.
  final ValueChanged<String>? onHistorySelected;

  const EditorSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.matches,
    required this.activeMatchIndex,
    required this.onSearch,
    required this.onJumpToMatch,
    required this.onJumpToNext,
    required this.onJumpToPrevious,
    required this.onClose,
    required this.searchOptions,
    required this.onOptionsChanged,
    this.showCandidates = false,
    this.searchHistory = const [],
    this.onHistorySelected,
  });

  @override
  State<EditorSearchBar> createState() => _EditorSearchBarState();
}

class _EditorSearchBarState extends State<EditorSearchBar> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appStyle = theme.extension<AppStyleTheme>()!;
    final displayMatches = widget.matches.take(5).toList(growable: false);
    final showCandidates =
        widget.showCandidates &&
        widget.controller.text.trim().isNotEmpty &&
        !_showHistory;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchInput(l10n, theme, appStyle),
          const SizedBox(height: 6),
          _buildOptionsRow(l10n, theme, appStyle),
          const SizedBox(height: 6),
          _buildCandidatesList(theme, appStyle, showCandidates, displayMatches),
        ],
      ),
    );
  }

  Widget _buildSearchInput(
    AppLocalizations l10n,
    ThemeData theme,
    AppStyleTheme appStyle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: appStyle.scaledSurfaceColor(theme.colorScheme, alpha: 0.98),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        onChanged: widget.onSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.searchContent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.searchHistory.isNotEmpty)
                IconButton(
                  tooltip: '搜索历史',
                  icon: Icon(
                    Icons.history,
                    size: 20,
                    color: _showHistory
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  onPressed: () {
                    setState(() => _showHistory = !_showHistory);
                  },
                ),
              IconButton(
                tooltip: l10n.closeSearch,
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (widget.controller.text.isNotEmpty) {
                    widget.controller.clear();
                    widget.onSearch('');
                    widget.focusNode.requestFocus();
                    return;
                  }
                  widget.focusNode.unfocus();
                  widget.onClose();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsRow(
    AppLocalizations l10n,
    ThemeData theme,
    AppStyleTheme appStyle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: appStyle.scaledSurfaceColor(theme.colorScheme, alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          // Case sensitive toggle
          _buildOptionButton(
            theme: theme,
            icon: Icons.text_fields,
            tooltip: '区分大小写',
            isActive: widget.searchOptions.caseSensitive,
            onPressed: () => widget.onOptionsChanged(
              widget.searchOptions.copyWith(
                caseSensitive: !widget.searchOptions.caseSensitive,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Whole word toggle
          _buildOptionButton(
            theme: theme,
            icon: Icons.space_bar,
            tooltip: '全词匹配',
            isActive: widget.searchOptions.wholeWord,
            onPressed: () => widget.onOptionsChanged(
              widget.searchOptions.copyWith(
                wholeWord: !widget.searchOptions.wholeWord,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Regex toggle
          _buildOptionButton(
            theme: theme,
            icon: Icons.code,
            tooltip: '正则表达式',
            isActive: widget.searchOptions.useRegex,
            onPressed: () => widget.onOptionsChanged(
              widget.searchOptions.copyWith(
                useRegex: !widget.searchOptions.useRegex,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Divider
          Container(
            width: 1,
            height: 20,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 8),
          // Match count
          Expanded(
            child: Text(
              widget.matches.isEmpty
                  ? l10n.noMatch
                  : '${widget.activeMatchIndex + 1}/${widget.matches.length}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          // Navigation buttons
          IconButton(
            tooltip: l10n.previous,
            visualDensity: VisualDensity.compact,
            onPressed: widget.matches.isEmpty ? null : widget.onJumpToPrevious,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: l10n.next,
            visualDensity: VisualDensity.compact,
            onPressed: widget.matches.isEmpty ? null : widget.onJumpToNext,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required ThemeData theme,
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildCandidatesList(
    ThemeData theme,
    AppStyleTheme appStyle,
    bool showCandidates,
    List<SearchMatch> displayMatches,
  ) {
    // Show history if toggled
    if (_showHistory && widget.searchHistory.isNotEmpty) {
      return _buildHistoryList(theme, appStyle);
    }

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: showCandidates
            ? Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: appStyle.scaledSurfaceColor(
                    theme.colorScheme,
                    alpha: 0.98,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 120),
                  child: displayMatches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            AppLocalizations.of(context)!.noMatchContent,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: displayMatches.length,
                          itemBuilder: (context, index) {
                            final match = displayMatches[index];
                            final isActive =
                                match.occurrence == widget.activeMatchIndex;
                            return ListTile(
                              dense: true,
                              selected: isActive,
                              title: Text(
                                match.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => widget.onJumpToMatch(match),
                            );
                          },
                        ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme, AppStyleTheme appStyle) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: appStyle.scaledSurfaceColor(theme.colorScheme, alpha: 0.98),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  '搜索历史',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.searchHistory.length,
              itemBuilder: (context, index) {
                final query = widget.searchHistory[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.search, size: 18),
                  title: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.controller.text = query;
                    widget.onSearch(query);
                    setState(() => _showHistory = false);
                    widget.onHistorySelected?.call(query);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
