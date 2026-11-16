import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/pdf_math_render_session.dart';

class _SessionPlatform extends InAppWebViewPlatform {
  _SessionPlatform({this.failLoading = false});

  final bool failLoading;
  late _SessionView view;

  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) => view = _SessionView(params, failLoading: failLoading);
}

class _SessionController extends PlatformInAppWebViewController {
  _SessionController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 99),
      );

  var checks = 0;

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {}

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async => ++checks >= 2;
}

class _SessionView extends PlatformHeadlessInAppWebView {
  _SessionView(super.params, {required this.failLoading})
    : super.implementation();

  final bool failLoading;
  final controller = _SessionController();
  var disposed = false;

  @override
  Future<void> run() async {
    final wrapped = params.controllerFromPlatform!(controller);
    params.onWebViewCreated?.call(wrapped);
    if (failLoading) {
      params.onReceivedError?.call(
        wrapped,
        WebResourceRequest(
          url: params.initialUrlRequest!.url!,
          isForMainFrame: true,
        ),
        WebResourceError(
          description: 'Synthetic load failure',
          type: WebResourceErrorType.HOST_LOOKUP,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return;
    }
    // Reproduce load completion preceding module availability, with its one-shot
    // JavaScript ready notification absent.
    params.onLoadStop?.call(wrapped, params.initialUrlRequest?.url);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('detects a renderer module that appears after onLoadStop', () async {
    final previous = InAppWebViewPlatform.instance;
    final platform = _SessionPlatform();
    InAppWebViewPlatform.instance = platform;
    try {
      final session = await PdfMathRenderSession.open().timeout(
        const Duration(seconds: 3),
      );
      expect(platform.view.controller.checks, greaterThanOrEqualTo(2));
      await session.dispose();
      expect(platform.view.disposed, isTrue);
    } finally {
      if (previous != null) InAppWebViewPlatform.instance = previous;
    }
  });

  test(
    'reports early page errors after native startup without leaking',
    () async {
      final previous = InAppWebViewPlatform.instance;
      final platform = _SessionPlatform(failLoading: true);
      InAppWebViewPlatform.instance = platform;
      try {
        await expectLater(PdfMathRenderSession.open(), throwsStateError);
        expect(platform.view.disposed, isTrue);
      } finally {
        if (previous != null) InAppWebViewPlatform.instance = previous;
      }
    },
  );
}
