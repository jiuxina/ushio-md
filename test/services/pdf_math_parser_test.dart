import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/pdf_math_parser.dart';

void main() {
  group('PdfMathDocument', () {
    test('extracts issue 129 inline formulas without changing TeX', () {
      const source =
          r'1. $\sin(-30^\circ)=$ and '
          r'$\sin\left(\dfrac{5\pi}{3}\right)=$, $x_i^2$.';
      final document = PdfMathDocument.parse(source);

      expect(document.expressions.values.map((expression) => expression.tex), [
        r'\sin(-30^\circ)=',
        r'\sin\left(\dfrac{5\pi}{3}\right)=',
        'x_i^2',
      ]);
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
      const source =
          r'Price \$5; `$x_i$` and ``$y$``.'
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
      const source =
          r'Unclosed $x'
          '\n'
          r'Complete $a+\$b$ and \$10.';
      final document = PdfMathDocument.parse(source);

      expect(document.restoreSource(document.markdown), source);
      expect(
        document.expressions.values.any(
          (expression) => expression.tex == r'a+\$b',
        ),
        isTrue,
      );
    });

    test('keeps nested code fences and currency outside math', () {
      const source =
          '  ```tex\n'
          r'  $notMath$'
          '\n  ```\n'
          r'It costs $5 and $10. The formula is $x_i$.';
      final document = PdfMathDocument.parse(source);

      expect(document.expressions.values.single.tex, 'x_i');
      expect(document.restoreSource(document.markdown), source);
    });

    test('generated markers cannot collide with the original text', () {
      const source = '\uE000MATH0\uE001 literal and \$x\$.';
      final document = PdfMathDocument.parse(source);
      expect(document.restoreSource(document.markdown), source);
    });

    test('keeps prices literal while accepting digit-led formulas', () {
      const source = r'Prices $5 and $10, but math $5$ and $10x$ works.';
      final document = PdfMathDocument.parse(source);

      expect(document.expressions.values.map((expression) => expression.tex), [
        '5',
        '10x',
      ]);
      expect(document.restoreSource(document.markdown), source);
    });

    test('does not consume another opener after an invalid closer', () {
      const source = r'Unclosed $x + later $y_i$ and $2z$.';
      final document = PdfMathDocument.parse(source);

      expect(document.expressions.values.map((expression) => expression.tex), [
        'y_i',
        '2z',
      ]);
      expect(document.restoreSource(document.markdown), source);
    });
  });
}
