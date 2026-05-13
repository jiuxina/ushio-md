/// Line-level diff calculator using LCS-based diff algorithm.
///
/// Computes line-by-line differences between two texts, producing
/// a list of [DiffLine] entries with added/removed/unchanged status
/// and corresponding line numbers for both old and new documents.
library;

/// The type of a single line in the diff result.
enum DiffLineType {
  /// Line was added in the new text.
  added,

  /// Line was removed from the old text.
  removed,

  /// Line is present in both old and new text (unchanged).
  unchanged,
}

/// A single line entry in the diff result.
///
/// Contains the line content, its change type, and the line numbers
/// in the original ([oldLineNumber]) and new ([newLineNumber]) documents.
/// A value of `null` for a line number means the line does not exist
/// in that document (e.g., an added line has no old line number).
class DiffLine {
  /// The text content of this line (without trailing newline).
  final String content;

  /// The change type of this line.
  final DiffLineType type;

  /// Line number in the old document (1-indexed), or `null` if added.
  final int? oldLineNumber;

  /// Line number in the new document (1-indexed), or `null` if removed.
  final int? newLineNumber;

  const DiffLine({
    required this.content,
    required this.type,
    this.oldLineNumber,
    this.newLineNumber,
  });

  @override
  String toString() =>
      'DiffLine(${type.name}, old:$oldLineNumber, new:$newLineNumber, '
      '"${_truncate(content, 30)}")';

  static String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}

/// The result of a line-level diff computation.
class DiffResult {
  /// All diff lines in order.
  final List<DiffLine> lines;

  /// Number of added lines.
  final int addedCount;

  /// Number of removed lines.
  final int removedCount;

  /// Number of unchanged lines.
  final int unchangedCount;

  const DiffResult({
    required this.lines,
    required this.addedCount,
    required this.removedCount,
    required this.unchangedCount,
  });

  /// Whether there are any differences.
  bool get hasChanges => addedCount > 0 || removedCount > 0;

  /// Total number of lines in the result.
  int get totalCount => lines.length;

  /// Empty diff result (no lines).
  static const empty = DiffResult(
    lines: [],
    addedCount: 0,
    removedCount: 0,
    unchangedCount: 0,
  );

  @override
  String toString() =>
      'DiffResult(+$addedCount -$removedCount =$unchangedCount, '
      '${lines.length} lines)';
}

/// Calculates line-level diff between [oldText] and [newText].
///
/// Uses an LCS (Longest Common Subsequence) based algorithm to find
/// matching lines between old and new text. Each line in the result
/// carries its content, change type, and the corresponding line numbers
/// in both documents.
DiffResult calculateLineDiff(String oldText, String newText) {
  // Fast path: identical strings
  if (oldText == newText) {
    if (oldText.isEmpty) return DiffResult.empty;
    final lines = oldText.split('\n');
    return DiffResult(
      lines: [
        for (var i = 0; i < lines.length; i++)
          DiffLine(
            content: lines[i],
            type: DiffLineType.unchanged,
            oldLineNumber: i + 1,
            newLineNumber: i + 1,
          ),
      ],
      addedCount: 0,
      removedCount: 0,
      unchangedCount: lines.length,
    );
  }

  // Fast path: one side empty
  if (oldText.isEmpty) {
    final lines = newText.split('\n');
    return DiffResult(
      lines: [
        for (var i = 0; i < lines.length; i++)
          DiffLine(
            content: lines[i],
            type: DiffLineType.added,
            newLineNumber: i + 1,
          ),
      ],
      addedCount: lines.length,
      removedCount: 0,
      unchangedCount: 0,
    );
  }
  if (newText.isEmpty) {
    final lines = oldText.split('\n');
    return DiffResult(
      lines: [
        for (var i = 0; i < lines.length; i++)
          DiffLine(
            content: lines[i],
            type: DiffLineType.removed,
            oldLineNumber: i + 1,
          ),
      ],
      addedCount: 0,
      removedCount: lines.length,
      unchangedCount: 0,
    );
  }

  final oldLines = oldText.split('\n');
  final newLines = newText.split('\n');

  final editScript = _computeDiff(oldLines, newLines);

  // Build result with line numbers
  final result = <DiffLine>[];
  var addedCount = 0;
  var removedCount = 0;
  var unchangedCount = 0;
  var oldLine = 1;
  var newLine = 1;

  for (final edit in editScript) {
    switch (edit.type) {
      case DiffLineType.unchanged:
        result.add(DiffLine(
          content: edit.content,
          type: DiffLineType.unchanged,
          oldLineNumber: oldLine,
          newLineNumber: newLine,
        ));
        oldLine++;
        newLine++;
        unchangedCount++;
      case DiffLineType.removed:
        result.add(DiffLine(
          content: edit.content,
          type: DiffLineType.removed,
          oldLineNumber: oldLine,
        ));
        oldLine++;
        removedCount++;
      case DiffLineType.added:
        result.add(DiffLine(
          content: edit.content,
          type: DiffLineType.added,
          newLineNumber: newLine,
        ));
        newLine++;
        addedCount++;
    }
  }

  return DiffResult(
    lines: result,
    addedCount: addedCount,
    removedCount: removedCount,
    unchangedCount: unchangedCount,
  );
}

// ---------------------------------------------------------------------------
// LCS-based diff internals
// ---------------------------------------------------------------------------

class _Edit {
  final String content;
  final DiffLineType type;
  const _Edit(this.content, this.type);
}

/// Computes the diff between [oldLines] and [newLines] using LCS.
///
/// First builds the LCS length table, then backtracks to produce
/// the edit script in order.
List<_Edit> _computeDiff(List<String> oldLines, List<String> newLines) {
  final n = oldLines.length;
  final m = newLines.length;

  // Build LCS length table: dp[i][j] = LCS length of oldLines[0..i-1], newLines[0..j-1]
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      if (oldLines[i - 1] == newLines[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1]
            ? dp[i - 1][j]
            : dp[i][j - 1];
      }
    }
  }

  // Backtrack to produce edit script (reversed)
  final edits = <_Edit>[];
  var i = n;
  var j = m;

  while (i > 0 && j > 0) {
    if (oldLines[i - 1] == newLines[j - 1]) {
      edits.add(_Edit(oldLines[i - 1], DiffLineType.unchanged));
      i--;
      j--;
    } else if (dp[i - 1][j] > dp[i][j - 1]) {
      edits.add(_Edit(oldLines[i - 1], DiffLineType.removed));
      i--;
    } else {
      edits.add(_Edit(newLines[j - 1], DiffLineType.added));
      j--;
    }
  }

  // Remaining old lines (all removed)
  while (i > 0) {
    edits.add(_Edit(oldLines[i - 1], DiffLineType.removed));
    i--;
  }

  // Remaining new lines (all added)
  while (j > 0) {
    edits.add(_Edit(newLines[j - 1], DiffLineType.added));
    j--;
  }

  return edits.reversed.toList();
}
