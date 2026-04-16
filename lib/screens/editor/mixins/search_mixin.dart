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

  /// Perform a search on the given text.
  ///
  /// Returns the number of matches found (capped at 50).
  int performSearch(String text, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _searchMatches = const [];
        _activeSearchMatchIndex = -1;
      });
      return 0;
    }

    final normalizedText = text.toLowerCase();
    final matches = <SearchMatch>[];
    var index = 0;

    while (matches.length < 50) {
      index = normalizedText.indexOf(normalizedQuery, index);
      if (index == -1) break;
      final start = (index - 20).clamp(0, text.length);
      final end = (index + normalizedQuery.length + 20).clamp(0, text.length);
      final preview = text.substring(start, end).replaceAll('\n', ' ');
      matches.add(
        SearchMatch(
          position: index,
          length: normalizedQuery.length,
          preview: preview,
          occurrence: matches.length,
        ),
      );
      index += normalizedQuery.length;
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
