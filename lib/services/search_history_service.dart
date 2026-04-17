/// Search history management service.
///
/// Provides persistent storage for recent search queries.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// A service for managing search history.
class SearchHistoryService {
  /// Maximum number of history items to store.
  static const int maxHistoryItems = 20;

  /// SharedPreferences key for search history.
  static const String _key = 'ushio_search_history';

  /// Get the list of recent search queries.
  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// Add a query to the search history.
  ///
  /// The query is added to the beginning of the list.
  /// Duplicate entries are moved to the front.
  /// The list is capped at [maxHistoryItems].
  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Get SharedPreferences instance once
    final prefs = await SharedPreferences.getInstance();
    var history = prefs.getStringList(_key) ?? [];

    // Remove duplicate if exists
    history.remove(trimmed);

    // Add to front
    history.insert(0, trimmed);

    // Cap the list size
    if (history.length > maxHistoryItems) {
      history.removeRange(maxHistoryItems, history.length);
    }

    await prefs.setStringList(_key, history);
  }

  /// Clear all search history.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Remove a specific query from history.
  Future<void> removeQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Get SharedPreferences instance once
    final prefs = await SharedPreferences.getInstance();
    var history = prefs.getStringList(_key) ?? [];

    history.remove(trimmed);
    await prefs.setStringList(_key, history);
  }
}
