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

    test('returns true for latex style delimiters without dollar signs', () {
      expect(
        markdownNeedsMathRendering(r'Inline: \(a^2+b^2=c^2\) and block: \[x+y\]'),
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

  group('webview preview background CSS vars', () {
    test('supports background config fields from settings sync', () {
      final widget = WebViewMarkdownPreview(
        data: '# Title',
        isDark: false,
        fontSize: 16,
        backgroundImagePath: '/tmp/bg.png',
        backgroundImageOpacity: 0.42,
        backgroundImageBlurEnabled: true,
        backgroundImageBlurSigma: 12.0,
        onCheckboxChanged: (_, __) {},
      );
      expect(widget.backgroundImagePath, '/tmp/bg.png');
      expect(widget.backgroundImageOpacity, 0.42);
      expect(widget.backgroundImageBlurEnabled, isTrue);
      expect(widget.backgroundImageBlurSigma, 12.0);
    });
  });
}
