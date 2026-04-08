/// Data models used by the editor screen.
///
/// These classes represent internal state and data structures
/// for editing, search, and block parsing functionality.
library;

import 'package:flutter/material.dart';

/// Represents a logical block of markdown content for inline editing.
///
/// Blocks are parsed from markdown text to enable single-tap editing
/// of related content (code blocks, tables, blockquotes, nested lists).
class MarkdownBlock {
  /// The starting line number (0-indexed) of this block.
  final int startLine;

  /// The ending line number (0-indexed) of this block.
  final int endLine;

  /// The raw markdown content of this block.
  final String content;

  /// Whether this block spans multiple lines.
  final bool isMultiLine;

  const MarkdownBlock({
    required this.startLine,
    required this.endLine,
    required this.content,
    required this.isMultiLine,
  });

  /// The number of lines in this block.
  int get lineCount => endLine - startLine + 1;

  @override
  String toString() =>
      'MarkdownBlock(start: $startLine, end: $endLine, multiLine: $isMultiLine)';
}

/// An entry in the edit history stack for undo/redo functionality.
class EditHistoryEntry {
  /// The text content at this history point.
  final String text;

  /// The cursor selection at this history point.
  final TextSelection selection;

  const EditHistoryEntry({required this.text, required this.selection});

  @override
  String toString() => 'EditHistoryEntry(text: ${text.length} chars)';
}

/// A search match result for inline search functionality.
class SearchMatch {
  /// The character position where the match starts.
  final int position;

  /// The length of the matched text.
  final int length;

  /// A preview snippet showing context around the match.
  final String preview;

  /// The 0-indexed occurrence number of this match.
  final int occurrence;

  const SearchMatch({
    required this.position,
    required this.length,
    required this.preview,
    required this.occurrence,
  });

  @override
  String toString() =>
      'SearchMatch(pos: $position, len: $length, occ: $occurrence)';
}
