// Synthetic device checks. Never loads the user's workspace or preferences.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/providers/file_provider.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/screens/editor_screen.dart';
import 'package:mdreader/services/export_service.dart';
import 'package:mdreader/services/milkdown_asset_server.dart';
import 'package:mdreader/services/pdf_math_render_session.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This dedicated device harness isolates preferences from the installed app.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  runApp(const DeviceRegressionApp());
}

class DeviceRegressionApp extends StatefulWidget {
  const DeviceRegressionApp({super.key});

  @override
  State<DeviceRegressionApp> createState() => _DeviceRegressionAppState();
}

class _DeviceRegressionAppState extends State<DeviceRegressionApp> {
  final settings = SettingsProvider();
  final files = FileProvider();
  final results = <String, Object?>{};
  final formulaImages = <Image>[];
  String? documentPath;
  String? editorUrl;
  String status = 'Starting synthetic checks';
  bool started = false;

  @override
  void initState() {
    super.initState();
    unawaited(runChecks());
  }

  Future<void> runChecks() async {
    try {
      final temp = await getTemporaryDirectory();
      final directory = await Directory(
        '${temp.path}/issue-regression-20261116',
      ).create(recursive: true);
      final document = File('${directory.path}/synthetic.md');
      await document.writeAsString(
        '# Synthetic regression\n\n'
        'Inline math: \$x_i^2\$ and \$\\sin(-30^\\circ)=\\frac12\$.\n\n'
        '```js\nconst selectedCode = true;\n```\n\n'
        '${List.generate(70, (i) => 'Paragraph $i: Tap and type here.\n').join('\n')}',
        flush: true,
      );
      documentPath = document.path;
      final session = await PdfMathRenderSession.open();
      try {
        for (final expression in [
          r'\sin(-30^\circ)=',
          r'\sin\left(\dfrac{5\pi}{3}\right)=',
          r'\sin(180^\circ-\alpha)\cdot\cos(360^\circ-\alpha)=',
        ]) {
          final image = await session.render(
            tex: expression,
            displayMode: false,
            fontSizePt: 12,
            maxWidthPt: 480,
          );
          if (image == null) throw StateError('Valid formula rejected');
          final index = formulaImages.length;
          await File(
            '${directory.path}/formula-$index.png',
          ).writeAsBytes(image.png);
          formulaImages.add(Image.memory(image.png, fit: BoxFit.contain));
          results['formula$index'] = {
            'bytes': image.png.length,
            'widthPt': image.widthPt,
            'heightPt': image.heightPt,
            'baselinePt': image.baselinePt,
          };
        }
        results['invalidTexPreserved'] =
            await session.render(
              tex: r'\unknownCommand{',
              displayMode: false,
              fontSizePt: 12,
              maxWidthPt: 480,
            ) ==
            null;
      } finally {
        await session.dispose();
      }
      final pdf = await ExportService.createPdfBytes(
        r'# Formula export'
        '\n\n'
        r'1. $\sin(-30^\circ)=$ ____'
        '\n\n'
        r'2. $\sin\left(\dfrac{5\pi}{3}\right)=$ ____'
        '\n\n'
        r'3. $\sin(180^\circ-\alpha)\cdot\cos(360^\circ-\alpha)=$ ____'
        '\n\n'
        r'$$\int_0^1 x^2\,dx = \frac13$$'
        '\n\n'
        r'Code: `$not_math$` and price \$5.',
        font: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
      );
      await File('${directory.path}/formula-export.pdf').writeAsBytes(pdf);
      results['pdfBytes'] = pdf.length;
      results['directory'] = directory.path;
      editorUrl = (await MilkdownAssetServer.ensureSharedStarted())
          .entryUri()
          .toString();
      await settings.setAutoSave(true);
      await settings.setFloatingButtonsMode('never');
      setState(() => status = 'PDF checks passed. Running editor checks.');
    } catch (error, stack) {
      results['error'] = '$error\n$stack';
      publish();
    }
  }

  Future<void> checkEditor(InAppWebViewController controller) async {
    if (started) return;
    started = true;
    try {
      final result = await controller
          .callAsyncJavaScript(
            functionBody: '''
          const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
          for (let n=0;n<300 && !window.__USHIO_BRIDGE__;n++) await wait(25);
          const bridge = window.__USHIO_BRIDGE__;
          if (!bridge) throw new Error('Bridge unavailable');
          const send = (type,payload) => bridge.onFlutterMessage({type,payload});
          send('exec_cmd',{cmd:'set_keyboard_metrics',
            args:{headerHeight:56,toolbarHeight:48,keyboardInset:0}});
          send('init_doc',{markdown:'# Synthetic title\\n\\nBefore text\\n\\n```js\\nconst test=1;\\n```\\n\\nEnd text',readOnly:false});
          for(let n=0;n<400;n++) {
            const state=window.__USHIO_PERF__?.contentState();
            if(state && !state.initializing && !state.applyingFromFlutter
              && document.querySelector('.ProseMirror p')) break;
            await wait(25);
          }
          const pristine=bridge.flushPendingChanges()===null;
          const top=parseFloat(getComputedStyle(document.querySelector('#app')).paddingTop);
          const p=document.querySelector('.ProseMirror p');
          p.closest('.ProseMirror').focus();
          const range=document.createRange();range.selectNodeContents(p);range.collapse(false);
          const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
          document.execCommand('insertText',false,' finalCharacters');
          await wait(0);
          const immediate=bridge.flushPendingChanges();
          window.__USHIO_PERF__.mountAllCodeBlocks();
          await wait(100);
          const code=document.querySelector('.cm-content');
          code.focus();
          const cr=document.createRange();cr.selectNodeContents(code);cr.collapse(false);
          selection.removeAllRanges();selection.addRange(cr);
          document.execCommand('insertText',false,' finalCode');
          await wait(0);
          const cmSnapshot=bridge.flushPendingChanges();
          send('exec_cmd',{cmd:'select_all'});
          document.execCommand('insertText',false,'replacement');
          await wait(0);
          const replaced=bridge.flushPendingChanges() || window.__USHIO_PERF__.serialize();
          return {pristine,top,immediate,cmSnapshot,replaced};
        ''',
          )
          .timeout(const Duration(seconds: 30));
      if (result?.error != null) throw StateError('${result!.error}');
      results['editor'] = result?.value;
      publish();
    } catch (error, stack) {
      results['editorError'] = '$error\n$stack';
      publish();
    }
  }

  void publish() {
    final output = jsonEncode(results);
    // One known tag, containing only generated test information.
    debugPrint('USHIO_REGRESSION $output', wrapWidth: 100000);
    if (mounted) setState(() => status = output);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: files),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: scheme,
          extensions: [
            AppStyleTheme.resolve(
              brightness: Brightness.light,
              colorScheme: scheme,
              backgroundColor: scheme.surface,
              textSecondary: scheme.onSurfaceVariant,
              buttonStyleMode: AppButtonStyleMode.classic,
              cardOpacity: 1,
            ),
          ],
        ),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Issue regression • synthetic data'),
            ),
            body: Column(
              children: [
                if (documentPath != null)
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditorScreen(filePath: documentPath!),
                      ),
                    ),
                    child: const Text('Open synthetic editor'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _DevicePerformancePage(),
                    ),
                  ),
                  child: const Text('Run synthetic performance'),
                ),
                ...formulaImages.map(
                  (image) => SizedBox(height: 50, child: image),
                ),
                SizedBox(
                  height: 140,
                  child: SingleChildScrollView(child: Text(status)),
                ),
                if (editorUrl != null)
                  Expanded(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(editorUrl!)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                      ),
                      onLoadStop: (controller, _) => checkEditor(controller),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevicePerformancePage extends StatelessWidget {
  const _DevicePerformancePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synthetic before/after benchmark')),
    body: InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(
          'http://127.0.0.1:4174/tools/editor-performance-oracle.html',
        ),
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'device_perf_result',
          callback: (arguments) {
            debugPrint(
              'USHIO_DEVICE_PERF ${jsonEncode(arguments)}',
              wrapWidth: 100000,
            );
            return null;
          },
        );
      },
      onLoadStop: (controller, _) => controller.evaluateJavascript(
        source: '''
              const check = setInterval(() => {
                if (/PASS|FAIL/.test(document.title)) {
                  clearInterval(check);
                  window.flutter_inappwebview.callHandler('device_perf_result',
                    document.querySelector('#result').textContent);
                }
              }, 1000);
            ''',
      ),
    ),
  );
}
