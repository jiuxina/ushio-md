import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/widgets/webview_markdown_preview.dart';

void main() {
  group('markdownNeedsMathRendering', () {
    test('returns false for ordinary markdown without math syntax', () {
      expect(
        markdownNeedsMathRendering(r'# Title' '\n\n' r'Price is $19.99.' '\n\n- item'),
        isFalse,
      );
    });

    test('returns true for inline math expressions', () {
      expect(
        markdownNeedsMathRendering(r'Energy formula: $E = mc^2$.'),
        isTrue,
      );
    });

    test('returns true for block math expressions', () {
      expect(
        markdownNeedsMathRendering('''Before

$$
\\int_0^1 x^2 dx
$$

After'''),
        isTrue,
      );
    });

    test('ignores escaped dollar signs', () {
      expect(
        markdownNeedsMathRendering(r'Total cost is \$25 and no formula here.'),
        isFalse,
      );
    });
  });
}
