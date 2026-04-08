/// Regex patterns used by the editor for parsing markdown.
///
/// These patterns are compiled once and reused for performance.
library;

/// Matches an unchecked checkbox: `- [ ]` with optional leading whitespace.
final uncheckedBoxRegex = RegExp(r'^(\s*-\s*)\[\s*\](.*)$');

/// Matches a checked checkbox: `- [x]` or `- [X]` with optional leading whitespace.
final checkedBoxRegex = RegExp(r'^(\s*-\s*)\[[xX]\](.*)$');

/// Pattern for splitting text into words (whitespace separator).
final wordSplitRegex = RegExp(r'\s+');

/// Matches the start of a code block (```).
final codeBlockStartRegex = RegExp(r'^\s*```');

/// Matches a table row starting with `|`.
final tableRowRegex = RegExp(r'^\s*\|');

/// Matches a blockquote line starting with `>`.
final blockquoteRegex = RegExp(r'^\s*>');

/// Matches the start of a list item (`-`, `*`, `+`, or `1.`).
final listItemStartRegex = RegExp(r'^\s*(?:[-*+]|\d+\.)\s+');

/// Matches indented content (2+ spaces followed by non-whitespace).
final indentedContentRegex = RegExp(r'^\s{2,}\S');

/// Matches a nested list marker (2+ spaces before list marker).
final nestedListMarkerRegex = RegExp(r'^\s{2,}(?:[-*+]|\d+\.)\s+');
