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
    this.showCandidates = false,
  });

  @override
  State<EditorSearchBar> createState() => _EditorSearchBarState();
}

class _EditorSearchBarState extends State<EditorSearchBar> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appStyle = theme.extension<AppStyleTheme>()!;
    final displayMatches = widget.matches.take(5).toList(growable: false);
    final showCandidates =
        widget.showCandidates && widget.controller.text.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchInput(l10n, theme, appStyle),
          const SizedBox(height: 8),
          _buildNavigationRow(l10n, theme, appStyle),
          const SizedBox(height: 8),
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
          suffixIcon: IconButton(
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
        ),
      ),
    );
  }

  Widget _buildNavigationRow(
    AppLocalizations l10n,
    ThemeData theme,
    AppStyleTheme appStyle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: appStyle.scaledSurfaceColor(theme.colorScheme, alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.matches.isEmpty
                  ? l10n.noMatch
                  : '${widget.activeMatchIndex + 1}/${widget.matches.length}',
              style: theme.textTheme.bodySmall,
            ),
          ),
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

  Widget _buildCandidatesList(
    ThemeData theme,
    AppStyleTheme appStyle,
    bool showCandidates,
    List<SearchMatch> displayMatches,
  ) {
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
}
