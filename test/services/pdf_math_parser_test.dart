import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/pdf_math_parser.dart';

void main() {
  group('PdfMathDocument', () {
    test('extracts issue 129 inline formulas without changing TeX', () {
      const source =
          r'1. $\sin(-30^\circ)=$ and '
          r'$\sin\left(\dfrac{5\pi}{3}\right)=$, $x_i^2$.';
      final document = PdfMathDocument.parse(source);

      expect(
        document.expressions.values.map((expression) => expression.tex),
        [
          r'\sin(-30^\circ)=',
          r'\sin\left(\dfrac{5\pi}{3}\right)=',
          'x_i^2',
        ],
      );
      expect(
        document.expressions.values.every(
          (expression) => !expression.displayMode,
        ),
        isTrue,
      );
      expect(document.restoreSource(document.markdown), source);
    });

    test('extracts multiline display math as a separate block', () {
      const source = 'Before\n\n\$\$\n\\frac{x_i}{2}\n\$\$\n\nAfter';
      final document = PdfMathDocument.parse(source);
      final expression = document.expressions.values.single;

      expect(expression.displayMode, isTrue);
      expect(expression.tex, '\\frac{x_i}{2}');
      expect(document.markdown, contains('\n\n${expression.marker}\n\n'));
    });

    test('does not interpret escaped dollars or code as math', () {
      const source = r'Price \$5; `$x_i$` and ``$y$``.'
          '\n```tex\n'
          r'$z$'
          '\n```\n~~~tex\n'
          r'$$w$$'
          '\n~~~\n'
          r'Actual $a_b$.';
      final document = PdfMathDocument.parse(source);

      expect(document.expressions.values.single.tex, 'a_b');
      expect(document.restoreSource(document.markdown), source);
    });

    test('keeps unmatched delimiters and escaped math closers intact', () {
      const source = r'Unclosed $x; complete $a+\$b$ and \$10.';
      final document = PdfMathDocument.parse(source);

      expect(document.restoreSource(document.markdown), source);
      expect(
        document.expressions.values.any(
          (expression) => expression.tex == r'a+\$b',
        ),
        isTrue,
      );
    });
  });
}
