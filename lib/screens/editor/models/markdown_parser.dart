/// Markdown block parsing for inline editing.
///
/// Parses markdown text into logical blocks for single-tap editing.
library;

import 'editor_models.dart';
import 'editor_patterns.dart';

/// Parses markdown text into logical blocks.
///
/// This enables single-tap editing of related content:
/// - Code blocks (``` to ```)
/// - Tables (contiguous | lines)
/// - Blockquotes (contiguous > lines)
/// - Nested lists (list item with indented continuations)
/// - Single lines (everything else)
List<MarkdownBlock> parseMarkdownBlocks(String text) {
  final lines = text.split('\n');
  final blocks = <MarkdownBlock>[];
  int i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // Code block: ``` to ```
    if (codeBlockStartRegex.hasMatch(trimmed)) {
      int end = i + 1;
      while (end < lines.length &&
          !codeBlockStartRegex.hasMatch(lines[end].trim())) {
        end++;
      }
      if (end < lines.length) end++; // include closing ```
      blocks.add(MarkdownBlock(
        startLine: i,
        endLine: end - 1,
        content: lines.sublist(i, end).join('\n'),
        isMultiLine: true,
      ));
      i = end;
      continue;
    }

    // Table: contiguous | lines (need at least 2 rows)
    if (tableRowRegex.hasMatch(trimmed) &&
        i + 1 < lines.length &&
        tableRowRegex.hasMatch(lines[i + 1].trim())) {
      int end = i;
      while (end < lines.length && tableRowRegex.hasMatch(lines[end].trim())) {
        end++;
      }
      blocks.add(MarkdownBlock(
        startLine: i,
        endLine: end - 1,
        content: lines.sublist(i, end).join('\n'),
        isMultiLine: true,
      ));
      i = end;
      continue;
    }

    // Blockquote: contiguous > lines
    if (blockquoteRegex.hasMatch(trimmed)) {
      int end = i;
      while (end < lines.length && blockquoteRegex.hasMatch(lines[end].trim())) {
        end++;
      }
      blocks.add(MarkdownBlock(
        startLine: i,
        endLine: end - 1,
        content: lines.sublist(i, end).join('\n'),
        isMultiLine: end > i + 1,
      ));
      i = end;
      continue;
    }

    // Nested list/continuation block:
    // Group a list item with its indented continuation lines (including
    // nested markers) so single-tap editing on nested markdown replaces the
    // whole logical unit instead of only one rendered <li>/<p> fragment.
    if (listItemStartRegex.hasMatch(trimmed)) {
      int end = i + 1;
      while (end < lines.length) {
        final next = lines[end];
        final nextTrim = next.trim();
        if (nextTrim.isEmpty) {
          end++;
          continue;
        }
        final isIndented = indentedContentRegex.hasMatch(next);
        final isNestedListMarker = nestedListMarkerRegex.hasMatch(next);
        if (!isIndented && !isNestedListMarker) break;
        end++;
      }
      blocks.add(MarkdownBlock(
        startLine: i,
        endLine: end - 1,
        content: lines.sublist(i, end).join('\n'),
        isMultiLine: end > i + 1,
      ));
      i = end;
      continue;
    }

    // Single line
    blocks.add(MarkdownBlock(
      startLine: i,
      endLine: i,
      content: line,
      isMultiLine: false,
    ));
    i++;
  }

  return blocks;
}

/// Toggle a checkbox in markdown text.
///
/// Returns the modified text, or null if the checkbox wasn't found or couldn't be toggled.
String? toggleCheckboxInText(String text, int checkboxIndex, bool newValue) {
  final lines = text.split('\n');
  int checkboxCount = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final uncheckedMatch = uncheckedBoxRegex.firstMatch(line);
    final checkedMatch = checkedBoxRegex.firstMatch(line);

    if (uncheckedMatch != null || checkedMatch != null) {
      if (checkboxCount == checkboxIndex) {
        if (newValue && uncheckedMatch != null) {
          lines[i] = '${uncheckedMatch.group(1)}[x]${uncheckedMatch.group(2)}';
          return lines.join('\n');
        } else if (!newValue && checkedMatch != null) {
          lines[i] = '${checkedMatch.group(1)}[ ]${checkedMatch.group(2)}';
          return lines.join('\n');
        }
        return null; // Already in desired state
      }
      checkboxCount++;
    }
  }

  return null; // Checkbox not found
}

/// Convert a heading text to a URL-friendly slug.
///
/// - Trims whitespace
/// - Removes leading numbers with separators
/// - Replaces spaces with hyphens
/// - Removes special characters (keeping letters, numbers, hyphens)
String slugifyHeading(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'^\d+[\.\-_\s]+'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
