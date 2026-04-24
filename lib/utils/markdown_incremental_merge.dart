// Incremental Markdown merge utility.
//
// This module provides block-level incremental merge functionality
// to preserve original Markdown formatting when only parts of the
// document are modified by the user.
//
// Key concept: When MilkDown serializes the ProseMirror document,
// it normalizes the entire document (e.g., --- to ***, - to *).
// By tracking which blocks changed and only replacing those blocks,
// we preserve the original formatting of unchanged blocks.

/// Represents a block in Markdown document.
///
/// A block is a logical unit separated by blank lines or specific
/// markers (headings, code fences, etc.)
class MarkdownBlock {
  /// The text content of this block (including newlines).
  final String content;

  /// Starting line number (0-indexed).
  final int startLine;

  /// Ending line number (0-indexed, inclusive).
  final int endLine;

  /// Block type for classification.
  final MarkdownBlockType type;

  const MarkdownBlock({
    required this.content,
    required this.startLine,
    required this.endLine,
    required this.type,
  });

  /// Number of lines in this block.
  int get lineCount => endLine - startLine + 1;

  @override
  String toString() => 'MarkdownBlock(type: $type, lines: $startLine-$endLine)';
}

/// Classification of Markdown block types.
enum MarkdownBlockType {
  /// Blank line(s).
  blank,

  /// ATX heading (# syntax).
  atxHeading,

  /// Setext heading (underline syntax).
  setextHeading,

  /// Code fence (``` or ~~~).
  codeFence,

  /// Indented code block.
  indentedCode,

  /// Blockquote.
  blockquote,

  /// Unordered list.
  unorderedList,

  /// Ordered list.
  orderedList,

  /// Task list.
  taskList,

  /// Thematic break (---, ***, ___).
  thematicBreak,

  /// HTML block.
  htmlBlock,

  /// Table (GFM).
  table,

  /// Math block ($$).
  mathBlock,

  /// Paragraph (default).
  paragraph,
}

/// Parses Markdown text into a list of blocks.
///
/// This parser identifies block boundaries while preserving original
/// formatting within each block.
List<MarkdownBlock> parseMarkdownBlocksForMerge(String markdown) {
  if (markdown.isEmpty) {
    return const [];
  }

  final lines = markdown.split('\n');
  final blocks = <MarkdownBlock>[];

  int i = 0;
  while (i < lines.length) {
    final block = _parseNextBlock(lines, i);
    blocks.add(block);
    i = block.endLine + 1;
  }

  return blocks;
}

/// Parse the next block starting from [startIndex].
MarkdownBlock _parseNextBlock(List<String> lines, int startIndex) {
  int i = startIndex;
  final startLine = i;

  // Check for blank lines
  if (lines[i].trim().isEmpty) {
    // Group consecutive blank lines
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    return MarkdownBlock(
      content: lines.sublist(startLine, i).join('\n') + (i < lines.length ? '\n' : ''),
      startLine: startLine,
      endLine: i - 1,
      type: MarkdownBlockType.blank,
    );
  }

  final line = lines[i];
  final trimmed = line.trim();

  // Check for code fence
  if (_isCodeFenceStart(trimmed)) {
    return _parseCodeFenceBlock(lines, startLine);
  }

  // Check for ATX heading
  if (_isAtxHeading(trimmed)) {
    return MarkdownBlock(
      content: line,
      startLine: startLine,
      endLine: startLine,
      type: MarkdownBlockType.atxHeading,
    );
  }

  // Check for thematic break
  if (_isThematicBreak(trimmed)) {
    return MarkdownBlock(
      content: line,
      startLine: startLine,
      endLine: startLine,
      type: MarkdownBlockType.thematicBreak,
    );
  }

  // Check for HTML block
  if (_isHtmlBlockStart(trimmed)) {
    return _parseHtmlBlock(lines, startLine);
  }

  // Check for blockquote
  if (trimmed.startsWith('>')) {
    return _parseBlockquote(lines, startLine);
  }

  // Check for list item
  if (_isUnorderedListItem(trimmed)) {
    return _parseListBlock(lines, startLine, MarkdownBlockType.unorderedList);
  }

  if (_isOrderedListItem(trimmed)) {
    return _parseListBlock(lines, startLine, MarkdownBlockType.orderedList);
  }

  if (_isTaskListItem(trimmed)) {
    return _parseListBlock(lines, startLine, MarkdownBlockType.taskList);
  }

  // Check for table
  if (_isTableLine(trimmed)) {
    return _parseTableBlock(lines, startLine);
  }

  // Check for math block
  if (trimmed.startsWith(r'$$')) {
    return _parseMathBlock(lines, startLine);
  }

  // Check for setext heading (next line is === or ---)
  if (i + 1 < lines.length && _isSetextUnderline(lines[i + 1].trim())) {
    return MarkdownBlock(
      content: '${lines[i]}\n${lines[i + 1]}',
      startLine: startLine,
      endLine: startLine + 1,
      type: MarkdownBlockType.setextHeading,
    );
  }

  // Default: paragraph
  return _parseParagraph(lines, startLine);
}

/// Check if line is a code fence start.
bool _isCodeFenceStart(String trimmed) {
  return trimmed.startsWith('```') || trimmed.startsWith('~~~');
}

/// Parse a code fence block.
MarkdownBlock _parseCodeFenceBlock(List<String> lines, int startIndex) {
  final fenceMatch = RegExp(r'^(`{3,}|~{3,})').firstMatch(lines[startIndex]);
  if (fenceMatch == null) {
    return MarkdownBlock(
      content: lines[startIndex],
      startLine: startIndex,
      endLine: startIndex,
      type: MarkdownBlockType.paragraph,
    );
  }

  final fenceMarker = fenceMatch.group(1)!;
  final fenceChar = fenceMarker[0];
  final fenceLen = fenceMarker.length;

  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith(fenceChar * fenceLen) ||
        trimmed.startsWith(fenceChar * (fenceLen + 1)) ||
        trimmed.startsWith(fenceChar * (fenceLen + 2))) {
      // Found closing fence
      return MarkdownBlock(
        content: lines.sublist(startIndex, i + 1).join('\n'),
        startLine: startIndex,
        endLine: i,
        type: MarkdownBlockType.codeFence,
      );
    }
    i++;
  }

  // Unclosed fence - treat rest as code
  return MarkdownBlock(
    content: lines.sublist(startIndex).join('\n'),
    startLine: startIndex,
    endLine: lines.length - 1,
    type: MarkdownBlockType.codeFence,
  );
}

/// Check if line is an ATX heading.
bool _isAtxHeading(String trimmed) {
  return RegExp(r'^#{1,6}\s+').hasMatch(trimmed);
}

/// Check if line is a thematic break.
bool _isThematicBreak(String trimmed) {
  // --- or *** or ___ with optional spaces, at least 3 chars
  return RegExp(r'^(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(trimmed);
}

/// Check if line starts an HTML block.
bool _isHtmlBlockStart(String trimmed) {
  // Common HTML block elements
  const htmlBlockTags = [
    'address', 'article', 'aside', 'base', 'basefont', 'blockquote',
    'body', 'caption', 'center', 'col', 'colgroup', 'dd', 'details',
    'dialog', 'dir', 'div', 'dl', 'dt', 'fieldset', 'figcaption',
    'figure', 'footer', 'form', 'frame', 'frameset', 'h1', 'h2',
    'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hr', 'html', 'iframe',
    'legend', 'li', 'link', 'main', 'menu', 'menuitem', 'nav',
    'noframes', 'ol', 'optgroup', 'option', 'p', 'param', 'section',
    'source', 'summary', 'table', 'tbody', 'td', 'tfoot', 'th',
    'thead', 'title', 'tr', 'track', 'ul',
  ];

  final lower = trimmed.toLowerCase();
  for (final tag in htmlBlockTags) {
    if (lower.startsWith('<$tag') || lower.startsWith('</$tag')) {
      return true;
    }
  }
  return false;
}

/// Parse an HTML block.
MarkdownBlock _parseHtmlBlock(List<String> lines, int startIndex) {
  // Simple: find blank line or end of HTML block
  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) break;
    // Check for closing tag or continuation
    i++;
  }
  return MarkdownBlock(
    content: lines.sublist(startIndex, i).join('\n'),
    startLine: startIndex,
    endLine: i - 1,
    type: MarkdownBlockType.htmlBlock,
  );
}

/// Parse a blockquote block.
MarkdownBlock _parseBlockquote(List<String> lines, int startIndex) {
  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty || !trimmed.startsWith('>')) break;
    i++;
  }
  return MarkdownBlock(
    content: lines.sublist(startIndex, i).join('\n'),
    startLine: startIndex,
    endLine: i - 1,
    type: MarkdownBlockType.blockquote,
  );
}

/// Check if line is an unordered list item.
bool _isUnorderedListItem(String trimmed) {
  return RegExp(r'^[-*+]\s+').hasMatch(trimmed);
}

/// Check if line is an ordered list item.
bool _isOrderedListItem(String trimmed) {
  return RegExp(r'^\d+\.\s+').hasMatch(trimmed);
}

/// Check if line is a task list item.
bool _isTaskListItem(String trimmed) {
  return RegExp(r'^[-*+]\s+\[[ xX]\]\s+').hasMatch(trimmed) ||
      RegExp(r'^\d+\.\s+\[[ xX]\]\s+').hasMatch(trimmed);
}

/// Parse a list block (handles nesting conservatively).
MarkdownBlock _parseListBlock(List<String> lines, int startIndex, MarkdownBlockType type) {
  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) break;
    // Continue if indented or another list item
    if (lines[i].startsWith('  ') ||
        lines[i].startsWith('\t') ||
        _isUnorderedListItem(trimmed) ||
        _isOrderedListItem(trimmed) ||
        _isTaskListItem(trimmed)) {
      i++;
    } else {
      break;
    }
  }
  return MarkdownBlock(
    content: lines.sublist(startIndex, i).join('\n'),
    startLine: startIndex,
    endLine: i - 1,
    type: type,
  );
}

/// Check if line could be part of a table.
bool _isTableLine(String trimmed) {
  return trimmed.contains('|');
}

/// Parse a table block.
MarkdownBlock _parseTableBlock(List<String> lines, int startIndex) {
  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty || !_isTableLine(trimmed)) break;
    i++;
  }
  return MarkdownBlock(
    content: lines.sublist(startIndex, i).join('\n'),
    startLine: startIndex,
    endLine: i - 1,
    type: MarkdownBlockType.table,
  );
}

/// Parse a math block.
MarkdownBlock _parseMathBlock(List<String> lines, int startIndex) {
  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed == r'$$') {
      i++;
      break;
    }
    i++;
  }
  return MarkdownBlock(
    content: lines.sublist(startIndex, i).join('\n'),
    startLine: startIndex,
    endLine: i - 1,
    type: MarkdownBlockType.mathBlock,
  );
}

/// Check if line is a setext underline.
bool _isSetextUnderline(String trimmed) {
  return RegExp(r'^=+$').hasMatch(trimmed) || RegExp(r'^-+$').hasMatch(trimmed);
}

/// Parse a paragraph block.
MarkdownBlock _parseParagraph(List<String> lines, int startIndex) {
  int i = startIndex + 1;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) break;
    // Check for block starts that would end the paragraph
    if (_isAtxHeading(trimmed) ||
        _isCodeFenceStart(trimmed) ||
        _isThematicBreak(trimmed) ||
        _isUnorderedListItem(trimmed) ||
        _isOrderedListItem(trimmed) ||
        trimmed.startsWith('>')) {
      break;
    }
    i++;
  }
  return MarkdownBlock(
    content: lines.sublist(startIndex, i).join('\n'),
    startLine: startIndex,
    endLine: i - 1,
    type: MarkdownBlockType.paragraph,
  );
}

/// Computes a normalized form for semantic comparison.
///
/// This function removes syntactic variations that MilkDown normalizes,
/// allowing blocks with different formatting to be recognized as equivalent.
String _normalizeForComparison(String content, MarkdownBlockType type) {
  final lines = content.split('\n');

  switch (type) {
    case MarkdownBlockType.thematicBreak:
      // All thematic breaks are semantically equivalent
      return 'THEMATIC_BREAK';

    case MarkdownBlockType.unorderedList:
    case MarkdownBlockType.taskList:
      // Normalize list markers: *, -, + all become -
      return lines.map((line) {
        final match = RegExp(r'^(\s*)([-*+])(\s+)').firstMatch(line);
        if (match != null) {
          return line.replaceFirst(
            RegExp(r'^(\s*)([-*+])(\s+)'),
            '${match.group(1)}-  ',
          );
        }
        return line;
      }).join('\n');

    case MarkdownBlockType.blank:
      return 'BLANK';

    default:
      return content.trim();
  }
}

/// Checks if two blocks are semantically equivalent despite formatting differences.
///
/// This is the core comparison function that detects when MilkDown has
/// normalized content that should be preserved in its original form.
bool _blocksAreSemanticallyEqual(
  MarkdownBlock original,
  MarkdownBlock newBlock,
) {
  // Same type is required
  if (original.type != newBlock.type) return false;

  // Thematic breaks: ---, ***, ___ are all equivalent
  if (original.type == MarkdownBlockType.thematicBreak) {
    return true;
  }

  // Blank lines are always equivalent
  if (original.type == MarkdownBlockType.blank) {
    return true;
  }

  // For lists, normalize markers before comparing
  if (original.type == MarkdownBlockType.unorderedList ||
      original.type == MarkdownBlockType.taskList) {
    final origNormalized = _normalizeForComparison(original.content, original.type);
    final newNormalized = _normalizeForComparison(newBlock.content, newBlock.type);
    return origNormalized == newNormalized;
  }

  // For other types, compare normalized content
  final origNormalized = _normalizeForComparison(original.content, original.type);
  final newNormalized = _normalizeForComparison(newBlock.content, newBlock.type);
  return origNormalized == newNormalized;
}

/// Result of incremental merge operation.
class IncrementalMergeResult {
  /// The merged Markdown content.
  final String content;

  /// Number of blocks preserved from original.
  final int preservedBlocks;

  /// Number of blocks replaced from new content.
  final int replacedBlocks;

  /// Whether any changes were made.
  final bool hasChanges;

  const IncrementalMergeResult({
    required this.content,
    required this.preservedBlocks,
    required this.replacedBlocks,
    required this.hasChanges,
  });
}

/// Performs incremental merge between original and new Markdown.
///
/// This function compares blocks between the original and new content,
/// preserving unchanged blocks from the original to maintain their
/// original formatting (e.g., --- vs ***, - vs *).
IncrementalMergeResult incrementalMerge({
  required String original,
  required String newContent,
}) {
  if (original == newContent) {
    return IncrementalMergeResult(
      content: original,
      preservedBlocks: 0,
      replacedBlocks: 0,
      hasChanges: false,
    );
  }

  if (original.isEmpty) {
    return IncrementalMergeResult(
      content: newContent,
      preservedBlocks: 0,
      replacedBlocks: 1,
      hasChanges: true,
    );
  }

  if (newContent.isEmpty) {
    return IncrementalMergeResult(
      content: '',
      preservedBlocks: 0,
      replacedBlocks: 0,
      hasChanges: true,
    );
  }

  final originalBlocks = parseMarkdownBlocksForMerge(original);
  final newBlocks = parseMarkdownBlocksForMerge(newContent);

  // If block counts differ significantly, fall back to full replacement
  // This handles cases like massive restructuring
  final lenDiff = (originalBlocks.length - newBlocks.length).abs();
  final threshold = (originalBlocks.length * 0.3).ceil().clamp(3, 50);

  if (lenDiff > threshold && lenDiff > 5) {
    // More than 30% difference - likely a major edit, use new content
    return IncrementalMergeResult(
      content: newContent,
      preservedBlocks: 0,
      replacedBlocks: newBlocks.length,
      hasChanges: true,
    );
  }

  // Track which original blocks are used
  final usedOriginal = List<bool>.filled(originalBlocks.length, false);
  final resultBlocks = <String>[];
  var preservedBlocks = 0;
  var replacedBlocks = 0;

  // Strategy: For each new block, try to find semantically equivalent original block
  for (var i = 0; i < newBlocks.length; i++) {
    final newBlock = newBlocks[i];
    var matched = false;

    // First, try exact position match (most common case)
    if (i < originalBlocks.length && !usedOriginal[i]) {
      if (_blocksAreSemanticallyEqual(originalBlocks[i], newBlock)) {
        resultBlocks.add(originalBlocks[i].content);
        usedOriginal[i] = true;
        preservedBlocks++;
        matched = true;
      }
    }

    // If no position match, search nearby blocks (within ±3 positions)
    if (!matched) {
      for (var offset = 1; offset <= 3; offset++) {
        // Check before
        final beforeIdx = i - offset;
        if (beforeIdx >= 0 && beforeIdx < originalBlocks.length && !usedOriginal[beforeIdx]) {
          if (_blocksAreSemanticallyEqual(originalBlocks[beforeIdx], newBlock)) {
            resultBlocks.add(originalBlocks[beforeIdx].content);
            usedOriginal[beforeIdx] = true;
            preservedBlocks++;
            matched = true;
            break;
          }
        }

        // Check after
        final afterIdx = i + offset;
        if (afterIdx >= 0 && afterIdx < originalBlocks.length && !usedOriginal[afterIdx]) {
          if (_blocksAreSemanticallyEqual(originalBlocks[afterIdx], newBlock)) {
            resultBlocks.add(originalBlocks[afterIdx].content);
            usedOriginal[afterIdx] = true;
            preservedBlocks++;
            matched = true;
            break;
          }
        }
      }
    }

    // No match found - use new block (this is a changed/new block)
    if (!matched) {
      resultBlocks.add(newBlock.content);
      replacedBlocks++;
    }
  }

  final mergedContent = resultBlocks.join('\n');

  return IncrementalMergeResult(
    content: mergedContent,
    preservedBlocks: preservedBlocks,
    replacedBlocks: replacedBlocks,
    hasChanges: preservedBlocks > 0 || replacedBlocks > 0,
  );
}
