/// A math span is protected before Markdown emphasis/link stripping runs.
class PdfMathExpression {
  const PdfMathExpression({
    required this.marker,
    required this.tex,
    required this.source,
    required this.displayMode,
  });

  final String marker;
  final String tex;
  final String source;
  final bool displayMode;
}

class PdfMathDocument {
  PdfMathDocument._(this.markdown, this.expressions);

  final String markdown;
  final Map<String, PdfMathExpression> expressions;

  static final markerPattern = RegExp('\uE000MATH[0-9]+\uE001');

  static PdfMathDocument parse(String source) {
    final expressions = <String, PdfMathExpression>{};
    final result = StringBuffer();
    var offset = 0;
    String? fenceCharacter;
    var fenceLength = 0;

    while (offset < source.length) {
      final lineStart = offset == 0 || source[offset - 1] == '\n';
      if (lineStart) {
        final newline = source.indexOf('\n', offset);
        final lineEnd = newline < 0 ? source.length : newline + 1;
        final line = source.substring(offset, lineEnd);
        final fence = RegExp(r'^[ \t]*(`{3,}|~{3,})').firstMatch(line);
        if (fenceCharacter != null) {
          result.write(line);
          if (fence != null &&
              fence.group(1)![0] == fenceCharacter &&
              fence.group(1)!.length >= fenceLength) {
            fenceCharacter = null;
          }
          offset = lineEnd;
          continue;
        }
        if (fence != null) {
          fenceCharacter = fence.group(1)![0];
          fenceLength = fence.group(1)!.length;
          result.write(line);
          offset = lineEnd;
          continue;
        }
      }

      if (source[offset] == r'\' && offset + 1 < source.length) {
        result.write(source.substring(offset, offset + 2));
        offset += 2;
        continue;
      }
      if (source[offset] == '`') {
        var end = offset + 1;
        while (end < source.length && source[end] == '`') {
          end++;
        }
        final delimiter = source.substring(offset, end);
        final closing = source.indexOf(delimiter, end);
        if (closing >= 0) end = closing + delimiter.length;
        result.write(source.substring(offset, end));
        offset = end;
        continue;
      }
      if (source[offset] != r'$') {
        result.write(source[offset++]);
        continue;
      }

      final display = offset + 1 < source.length && source[offset + 1] == r'$';
      final delimiter = display ? r'$$' : r'$';
      final contentStart = offset + delimiter.length;
      if (!display &&
          (contentStart == source.length ||
              RegExp(r'\s').hasMatch(source[contentStart]))) {
        result.write(source[offset++]);
        continue;
      }
      var closing = contentStart;
      var foundClosing = false;
      while (closing < source.length) {
        if (source[closing] == r'\') {
          closing += 2;
          continue;
        }
        if (!display && source[closing] == '\n') break;
        if (source.startsWith(delimiter, closing)) {
          final afterClosing = closing + delimiter.length;
          foundClosing =
              display ||
              (closing > contentStart &&
                  !RegExp(r'\s').hasMatch(source[closing - 1]) &&
                  (afterClosing == source.length ||
                      !RegExp(r'[0-9]').hasMatch(source[afterClosing])));
          // An invalid closer can start a later independent expression.
          // Never absorb it and the rest of a price-bearing paragraph.
          break;
        }
        closing++;
      }
      if (!foundClosing ||
          source.substring(contentStart, closing).trim().isEmpty) {
        result.write(source[offset++]);
        continue;
      }

      final end = closing + delimiter.length;
      var markerIndex = expressions.length;
      var marker = '\uE000MATH$markerIndex\uE001';
      while (source.contains(marker) || expressions.containsKey(marker)) {
        marker = '\uE000MATH${++markerIndex}\uE001';
      }
      expressions[marker] = PdfMathExpression(
        marker: marker,
        tex: source.substring(contentStart, closing).trim(),
        source: source.substring(offset, end),
        displayMode: display,
      );
      if (display) result.write('\n\n');
      result.write(marker);
      if (display) result.write('\n\n');
      offset = end;
    }
    return PdfMathDocument._(result.toString(), expressions);
  }

  String restoreSource(String value) => value.replaceAllMapped(
    markerPattern,
    (match) => expressions[match.group(0)]?.source ?? match.group(0)!,
  );
}
