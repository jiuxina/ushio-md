import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'milkdown_asset_server.dart';

class PdfMathImage {
  const PdfMathImage({
    required this.png,
    required this.widthPt,
    required this.heightPt,
    required this.baselinePt,
  });

  final Uint8List png;
  final double widthPt;
  final double heightPt;

  /// Distance from the top edge of the image to the text baseline.
  final double baselinePt;
}

class _FormulaBounds {
  _FormulaBounds(Map value)
    : x = _number(value, 'x'),
      y = _number(value, 'y'),
      width = _number(value, 'width'),
      height = _number(value, 'height'),
      baseline = _number(value, 'baseline'),
      pixelRatio = _number(value, 'pixelRatio') {
    if (width <= 0 ||
        height <= 0 ||
        pixelRatio <= 0 ||
        baseline > height ||
        viewport.width * pixelRatio > 8192 ||
        viewport.height * pixelRatio > 8192 ||
        viewport.width * viewport.height * pixelRatio * pixelRatio > 16777216) {
      throw StateError('Formula exceeds safe screenshot bounds');
    }
  }

  final double x;
  final double y;
  final double width;
  final double height;
  final double baseline;
  final double pixelRatio;

  Size get viewport =>
      Size((x + width + 2).ceilToDouble(), (y + height + 2).ceilToDouble());

  bool fits(Size size) => x + width <= size.width && y + height <= size.height;

  static double _number(Map value, String key) {
    final number = value[key];
    if (number is! num || !number.isFinite || number < 0) {
      throw StateError('Invalid formula layout: $key');
    }
    return number.toDouble();
  }
}

/// One offscreen KaTeX renderer is reused for all formulas in an export.
abstract class PdfMathRenderSession {
  static Future<PdfMathRenderSession> open() =>
      _HeadlessPdfMathRenderSession.open();

  /// Invalid TeX returns null so the original expression remains visible.
  Future<PdfMathImage?> render({
    required String tex,
    required bool displayMode,
    required double fontSizePt,
    required double maxWidthPt,
  });

  Future<void> dispose();
}

class _HeadlessPdfMathRenderSession implements PdfMathRenderSession {
  static const _timeout = Duration(seconds: 15);
  // Render at 3x the CSS-to-PDF conversion for crisp formulas when printed.
  static const _pixelsPerPoint = 4.0;

  late final HeadlessInAppWebView _webView;
  InAppWebViewController? _controller;
  bool _disposed = false;

  static Future<PdfMathRenderSession> open() async {
    final session = _HeadlessPdfMathRenderSession();
    final ready = Completer<void>();
    final server = await MilkdownAssetServer.ensureSharedStarted();
    session._webView = HeadlessInAppWebView(
      initialSize: const Size(2200, 800),
      initialUrlRequest: URLRequest(
        url: WebUri.uri(server.entryUri('pdf-math.html')),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
        disableContextMenu: true,
        supportZoom: false,
      ),
      onWebViewCreated: (controller) {
        session._controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'pdf_math_ready',
          callback: (_) {
            if (!ready.isCompleted) ready.complete();
            return null;
          },
        );
      },
      onLoadStop: (controller, _) async {
        // Modules may finish before the platform installs the JS handler.
        final available = await controller.evaluateJavascript(
          source: 'Boolean(window.__USHIO_PDF_MATH__)',
        );
        if (available == true && !ready.isCompleted) ready.complete();
      },
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame == true && !ready.isCompleted) {
          ready.completeError(StateError('Formula page: ${error.description}'));
        }
      },
    );
    try {
      await Future.wait<void>([
        session._webView.run(),
        ready.future,
      ]).timeout(_timeout);
      return session;
    } catch (_) {
      await session.dispose();
      rethrow;
    }
  }

  @override
  Future<PdfMathImage?> render({
    required String tex,
    required bool displayMode,
    required double fontSizePt,
    required double maxWidthPt,
  }) async {
    final controller = _controller;
    if (_disposed || controller == null) {
      throw StateError('Formula renderer is not available');
    }
    final result = await controller
        .callAsyncJavaScript(
          functionBody: 'return await window.__USHIO_PDF_MATH__.render(args);',
          arguments: {
            'args': {
              'tex': tex,
              'displayMode': displayMode,
              'fontSizePx': fontSizePt * _pixelsPerPoint,
              'maxWidthPx': maxWidthPt * _pixelsPerPoint,
            },
          },
        )
        .timeout(_timeout);
    if (result?.error != null) {
      throw StateError('Formula render failed: ${result!.error}');
    }
    final value = result?.value;
    if (value is! Map) throw StateError('Formula renderer returned no layout');
    if (value['invalid'] == true) return null;
    var bounds = _FormulaBounds(value);
    var viewport = bounds.viewport;
    for (var attempt = 0; attempt < 3; attempt++) {
      await _webView.setSize(viewport).timeout(_timeout);
      // INVISIBLE Android WebViews throttle rAF. Re-read every crop dimension
      // and the baseline after native resizing, without waiting for a frame.
      final settled = await controller
          .callAsyncJavaScript(
            functionBody:
                'await new Promise(resolve => setTimeout(resolve, 32));'
                'return await window.__USHIO_PDF_MATH__.measure();',
          )
          .timeout(_timeout);
      final layout = settled?.value;
      if (settled?.error != null || layout is! Map) {
        throw StateError('Formula layout did not settle: ${settled?.error}');
      }
      bounds = _FormulaBounds(layout);
      if (bounds.fits(viewport)) break;
      if (attempt == 2) throw StateError('Formula layout did not stabilize');
      viewport = bounds.viewport;
    }
    final png = await controller
        .takeScreenshot(
          screenshotConfiguration: ScreenshotConfiguration(
            rect: InAppWebViewRect(
              x: bounds.x,
              y: bounds.y,
              width: bounds.width,
              height: bounds.height,
            ),
          ),
        )
        .timeout(_timeout);
    if (png == null || png.isEmpty) {
      throw StateError('Formula screenshot was empty');
    }
    return PdfMathImage(
      png: png,
      widthPt: bounds.width / _pixelsPerPoint,
      heightPt: bounds.height / _pixelsPerPoint,
      baselinePt: bounds.baseline / _pixelsPerPoint,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controller = null;
    await _webView.dispose();
  }
}
