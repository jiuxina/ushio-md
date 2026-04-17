/// Search functionality for the editor.
///
/// Provides inline search with match highlighting and navigation.
library;

import 'package:flutter/material.dart';
import '../models/editor_models.dart';

/// A mixin that provides search functionality for text editing.
///
/// Usage:
/// ```dart
/// class _MyEditorState extends State<MyEditor> with SearchMixin {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///   }
///
///   void doSearch() {
///     performSearch(_controller.text, 'search query');
///     if (searchMatches.isNotEmpty) {
///       jumpToMatch(0);
///     }
///   }
/// }
/// ```
mixin SearchMixin<T extends StatefulWidget> on State<T> {
  /// Current search matches.
  List<SearchMatch> get searchMatches => _searchMatches;
  List<SearchMatch> _searchMatches = const [];

  /// Index of the currently active match (-1 if none).
  int get activeSearchMatchIndex => _activeSearchMatchIndex;
  int _activeSearchMatchIndex = -1;

  /// Maximum number of search results to return.
  static const int maxSearchResults = 100;

  /// Extract a preview snippet around a match position.
  String _extractPreview(String text, int position, int length) {
    final start = (position - 20).clamp(0, text.length);
    final end = (position + length + 20).clamp(0, text.length);
    return text.substring(start, end).replaceAll('\n', ' ');
  }

  /// Perform a search on the given text.
  ///
  /// Returns the number of matches found (capped at [maxSearchResults]).
  int performSearch(
    String text,
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _searchMatches = const [];
        _activeSearchMatchIndex = -1;
      });
      return 0;
    }

    final matches = <SearchMatch>[];

    if (options.useRegex) {
      // Regular expression search
      try {
        final regex = RegExp(
          normalizedQuery,
          caseSensitive: options.caseSensitive,
        );
        for (final match in regex.allMatches(text)) {
          if (matches.length >= maxSearchResults) break;
          matches.add(
            SearchMatch(
              position: match.start,
              length: match.end - match.start,
              preview: _extractPreview(
                text,
                match.start,
                match.end - match.start,
              ),
              occurrence: matches.length,
            ),
          );
        }
      } catch (_) {
        // Invalid regular expression - return empty results
      }
    } else if (options.wholeWord) {
      // Whole word matching
      final wordPattern = RegExp(
        r'\b' + RegExp.escape(normalizedQuery) + r'\b',
        caseSensitive: options.caseSensitive,
      );
      for (final match in wordPattern.allMatches(text)) {
        if (matches.length >= maxSearchResults) break;
        matches.add(
          SearchMatch(
            position: match.start,
            length: match.end - match.start,
            preview: _extractPreview(
              text,
              match.start,
              match.end - match.start,
            ),
            occurrence: matches.length,
          ),
        );
      }
    } else {
      // Standard substring search
      final searchText = options.caseSensitive ? text : text.toLowerCase();
      final searchQuery = options.caseSensitive
          ? normalizedQuery
          : normalizedQuery.toLowerCase();
      var index = 0;

      while (matches.length < maxSearchResults) {
        index = searchText.indexOf(searchQuery, index);
        if (index == -1) break;
        matches.add(
          SearchMatch(
            position: index,
            length: searchQuery.length,
            preview: _extractPreview(text, index, searchQuery.length),
            occurrence: matches.length,
          ),
        );
        index += searchQuery.length;
      }
    }

    setState(() {
      _searchMatches = matches;
      _activeSearchMatchIndex = matches.isEmpty ? -1 : 0;
    });

    return matches.length;
  }

  /// Clear search results.
  void clearSearch() {
    setState(() {
      _searchMatches = const [];
      _activeSearchMatchIndex = -1;
    });
  }

  /// Jump to a specific match by index.
  ///
  /// Returns the match that was jumped to, or null if invalid.
  SearchMatch? jumpToMatch(int index) {
    if (_searchMatches.isEmpty) return null;
    final clamped = index.clamp(0, _searchMatches.length - 1);
    setState(() => _activeSearchMatchIndex = clamped);
    return _searchMatches[clamped];
  }

  /// Jump to the next match.
  ///
  /// Returns the match that was jumped to, or null if no matches.
  SearchMatch? jumpToNextMatch() {
    if (_searchMatches.isEmpty) return null;
    final next = _activeSearchMatchIndex < 0
        ? 0
        : (_activeSearchMatchIndex + 1) % _searchMatches.length;
    return jumpToMatch(next);
  }

  /// Jump to the previous match.
  ///
  /// Returns the match that was jumped to, or null if no matches.
  SearchMatch? jumpToPrevMatch() {
    if (_searchMatches.isEmpty) return null;
    final prev = _activeSearchMatchIndex < 0
        ? 0
        : (_activeSearchMatchIndex - 1 + _searchMatches.length) %
              _searchMatches.length;
    return jumpToMatch(prev);
  }

  /// Get a search match by index.
  SearchMatch? getMatch(int index) {
    if (index < 0 || index >= _searchMatches.length) return null;
    return _searchMatches[index];
  }

  /// Get the total number of matches.
  int get matchCount => _searchMatches.length;
}
