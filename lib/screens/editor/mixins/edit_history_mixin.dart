/// Edit history management for undo/redo functionality.
///
/// This mixin provides a complete undo/redo stack implementation
/// that can be attached to any widget that needs edit history.
library;

import 'package:flutter/material.dart';
import 'editor_models.dart';

/// A mixin that provides undo/redo functionality for text editing.
///
/// Usage:
/// ```dart
/// class _MyEditorState extends State<MyEditor> with EditHistoryMixin {
///   late TextEditingController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = TextEditingController();
///     initHistory(_controller.text);
///     _controller.addListener(() => recordHistory(_controller.text));
///   }
///
///   void undo() => applyUndo((text, sel) {
///     _controller.value = TextEditingValue(text: text, selection: sel);
///   });
/// }
/// ```
mixin EditHistoryMixin<T extends StatefulWidget> on State<T> {
  /// Maximum number of history entries to keep.
  static const int maxEditHistory = 100;

  /// The history stack.
  final List<EditHistoryEntry> _editHistory = [];

  /// Current position in the history stack.
  int _historyIndex = -1;

  /// Flag to prevent recording during programmatic changes.
  bool _isApplyingHistory = false;

  /// Initialize history with the initial content.
  void initHistory(String text, {TextSelection? selection}) {
    _editHistory
      ..clear()
      ..add(EditHistoryEntry(
        text: text,
        selection: selection ?? const TextSelection.collapsed(offset: 0),
      ));
    _historyIndex = 0;
  }

  /// Record a new history entry.
  ///
  /// Call this whenever the text changes (via listener).
  /// If [reset] is true, clears existing history and starts fresh.
  void recordHistory(String text, {TextSelection? selection, bool reset = false}) {
    if (_isApplyingHistory) return;

    final safe = _safeSelection(selection, text.length);

    if (reset) {
      _editHistory
        ..clear()
        ..add(EditHistoryEntry(text: text, selection: safe));
      _historyIndex = 0;
      return;
    }

    // Skip if content unchanged
    if (_historyIndex >= 0 && _historyIndex < _editHistory.length) {
      if (_editHistory[_historyIndex].text == text) return;
    }

    // Remove future history if we're not at the end
    if (_historyIndex < _editHistory.length - 1) {
      _editHistory.removeRange(_historyIndex + 1, _editHistory.length);
    }

    _editHistory.add(EditHistoryEntry(text: text, selection: safe));

    // Trim old entries if exceeding max
    if (_editHistory.length > maxEditHistory) {
      final overflow = _editHistory.length - maxEditHistory;
      _editHistory.removeRange(0, overflow);
      _historyIndex = (_historyIndex - overflow).clamp(0, _editHistory.length - 1);
    }

    _historyIndex = _editHistory.length - 1;
  }

  /// Whether undo is available.
  bool get canUndo => _historyIndex > 0;

  /// Whether redo is available.
  bool get canRedo => _historyIndex >= 0 && _historyIndex < _editHistory.length - 1;

  /// Apply undo operation.
  ///
  /// [apply] is called with the text and selection to restore.
  /// Returns true if undo was applied, false if not possible.
  bool applyUndo(void Function(String text, TextSelection selection) apply) {
    if (!canUndo) return false;
    _historyIndex--;
    final entry = _editHistory[_historyIndex];
    _isApplyingHistory = true;
    apply(entry.text, entry.selection);
    _isApplyingHistory = false;
    return true;
  }

  /// Apply redo operation.
  ///
  /// [apply] is called with the text and selection to restore.
  /// Returns true if redo was applied, false if not possible.
  bool applyRedo(void Function(String text, TextSelection selection) apply) {
    if (!canRedo) return false;
    _historyIndex++;
    final entry = _editHistory[_historyIndex];
    _isApplyingHistory = true;
    apply(entry.text, entry.selection);
    _isApplyingHistory = false;
    return true;
  }

  /// Get the current text from history.
  String? get currentText =>
      _historyIndex >= 0 && _historyIndex < _editHistory.length
          ? _editHistory[_historyIndex].text
          : null;

  /// Get the current selection from history.
  TextSelection? get currentSelection =>
      _historyIndex >= 0 && _historyIndex < _editHistory.length
          ? _editHistory[_historyIndex].selection
          : null;

  /// Safely clamp a selection to text bounds.
  TextSelection _safeSelection(TextSelection? sel, int textLength) {
    if (sel == null) return TextSelection.collapsed(offset: 0);
    final base = sel.baseOffset.clamp(0, textLength).toInt();
    final extent = sel.extentOffset.clamp(0, textLength).toInt();
    return TextSelection(baseOffset: base, extentOffset: extent);
  }

  /// Clear all history.
  void clearHistory() {
    _editHistory.clear();
    _historyIndex = -1;
  }

  /// Must be called in dispose to clean up.
  void disposeHistory() {
    _editHistory.clear();
  }
}
