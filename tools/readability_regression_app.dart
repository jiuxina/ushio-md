// Synthetic visual checks: no app initialization, saved settings, or user files.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import 'package:mdreader/l10n/app_localizations.dart';
import 'package:mdreader/models/milkdown_bridge.dart';
import 'package:mdreader/services/milkdown_asset_server.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mdreader/utils/constants.dart';
import 'package:mdreader/utils/theme_tones.dart';
import 'package:mdreader/widgets/app_modal.dart';
import 'package:mdreader/widgets/app_surface.dart';
import 'package:mdreader/widgets/glass_card.dart';
import 'package:mdreader/widgets/settings_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const ReadabilityRegressionApp(),
    ),
  );
}

class ReadabilityRegressionApp extends StatefulWidget {
  const ReadabilityRegressionApp({super.key});

  @override
  State<ReadabilityRegressionApp> createState() =>
      _ReadabilityRegressionAppState();
}

class _ReadabilityRegressionAppState extends State<ReadabilityRegressionApp> {
  bool dark = const bool.fromEnvironment('READABILITY_DARK');
  bool largeText = const bool.fromEnvironment('READABILITY_LARGE_TEXT');
  bool web = const bool.fromEnvironment('READABILITY_WEB');
  bool narrow = const bool.fromEnvironment('READABILITY_NARROW');
  double opacity =
      double.tryParse(
        const String.fromEnvironment(
          'READABILITY_OPACITY',
          defaultValue: '0.1',
        ),
      ) ??
      0.1;
  String backdrop = const String.fromEnvironment(
    'READABILITY_BACKDROP',
    defaultValue: 'checkerboard',
  );
  String cardColor = const String.fromEnvironment(
    'READABILITY_CARD',
    defaultValue: 'black',
  );
  AppButtonStyleMode style = AppButtonStyleMode.values.firstWhere(
    (value) =>
        value.name ==
        const String.fromEnvironment(
          'READABILITY_STYLE',
          defaultValue: 'liquidGlass',
        ),
    orElse: () => AppButtonStyleMode.liquidGlass,
  );

  Color? get customCardColor => switch (cardColor) {
    'black' => const Color(0xFF101319),
    'white' => Colors.white,
    'purple' => const Color(0xFF625285),
    _ => null,
  };

  ThemeData buildTheme() {
    final paper = dark
        ? AppConstants.darkThemeSchemes.first
        : AppConstants.lightThemeSchemes.first;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final scheme = ThemeTones.scheme(
      brightness: brightness,
      primary: const Color(0xFF625285),
      themeScheme: paper,
      error: AppConstants.errorColor,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: ThemeData(
        brightness: brightness,
      ).textTheme.apply(bodyColor: paper.text, displayColor: paper.text),
      extensions: [
        AppStyleTheme.resolve(
          brightness: brightness,
          colorScheme: scheme,
          backgroundColor: paper.background,
          textSecondary: paper.textSecondary,
          buttonStyleMode: style,
          cardOpacity: opacity,
          customCardColor: customCardColor,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = buildTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      theme: theme,
      builder: (context, child) {
        final content = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
          child: child!,
        );
        if (style != AppButtonStyleMode.liquidGlass) return content;
        return GlassPage(
          settings: LiquidGlassSettings(
            glassColor: dark
                ? const Color(0x2E101828)
                : const Color(0x66FFFFFF),
            blur: 16,
            platformViewMode: PlatformViewGlassMode.passthrough,
          ),
          statusBarStyle: GlassStatusBarStyle.none,
          child: content,
        );
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: CustomPaint(
            painter: _FixtureBackdrop(backdrop),
            child: SafeArea(
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                    ),
                    child: SingleChildScrollView(child: _controls(context)),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: narrow ? 320 : 900,
                        ),
                        child: web
                            ? const _SyntheticWebPage()
                            : _cards(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(8),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('可读性检查 · 生成数据'),
        TextButton(
          onPressed: () => setState(() => dark = !dark),
          child: Text(dark ? '深色' : '浅色'),
        ),
        TextButton(
          onPressed: () => setState(() {
            style = AppButtonStyleMode
                .values[(style.index + 1) % AppButtonStyleMode.values.length];
          }),
          child: Text(style.name),
        ),
        TextButton(
          onPressed: () => setState(() {
            const values = ['black', 'white', 'purple', 'theme'];
            cardColor = values[(values.indexOf(cardColor) + 1) % values.length];
          }),
          child: Text('卡片 $cardColor'),
        ),
        TextButton(
          onPressed: () => setState(() => opacity = opacity < 0.5 ? 1 : 0.1),
          child: Text('透明度 ${opacity.toStringAsFixed(1)}'),
        ),
        TextButton(
          onPressed: () => setState(() {
            const values = ['checkerboard', 'black', 'white'];
            backdrop = values[(values.indexOf(backdrop) + 1) % values.length];
          }),
          child: Text('背景 $backdrop'),
        ),
        TextButton(
          onPressed: () => setState(() => largeText = !largeText),
          child: Text(largeText ? '字号 200%' : '字号 100%'),
        ),
        TextButton(
          onPressed: () => setState(() => narrow = !narrow),
          child: Text(narrow ? '宽度 320' : '适应宽度'),
        ),
        TextButton(
          onPressed: () => setState(() => web = !web),
          child: Text(web ? '查看卡片' : '查看 Web 浮层'),
        ),
      ],
    ),
  );

  Widget _cards(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      GlassCard(
        icon: Icons.description_outlined,
        title: '示例文档 — Readability sample',
        subtitle: '2.4 KB · 2026/11/20 12:00 · 完全生成的测试信息',
        onTap: () => _showDialog(context),
        trailing: const Icon(Icons.chevron_right),
      ),
      const SizedBox(height: 12),
      SettingsSection(
        title: '长标题设置区块与字体可读性 Readable settings section',
        icon: Icons.tune,
        children: [
          const Text('主文字：内容与当前设置应清晰可辨。'),
          const SizedBox(height: 8),
          Builder(
            builder: (context) => Text(
              '次要说明：背景黑白交错、卡片颜色和大字号变化时仍能阅读。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: '示例输入',
              hintText: '请输入测试内容',
              helperText: '辅助说明文本，不读取或保存任何用户内容',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _showDialog(context),
                child: const Text('打开对话框'),
              ),
              OutlinedButton(
                onPressed: () => _showSheet(context),
                child: const Text('打开底部面板'),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Future<void> _showDialog(BuildContext context) => showAppDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('确认测试操作 Confirm generated fixture'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('这是生成的对话框内容。请检查标题、正文、辅助说明和按钮。'),
          const SizedBox(height: 12),
          Text(
            '文件路径：/synthetic/demo/readability-example.md',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: '测试名称',
              hintText: '生成的示例名称',
              errorText: '错误说明示例，请保持清晰可读',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消 Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('确认 Confirm'),
        ),
      ],
    ),
  );

  Future<void> _showSheet(BuildContext context) =>
      showAppModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '底部面板 Bottom sheet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text('面板底色应隔开复杂背景，设置列表中的文字仍然清晰。'),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('示例设置项目'),
                  subtitle: const Text('完整说明 · Generated fixture only'),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭面板'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _FixtureBackdrop extends CustomPainter {
  const _FixtureBackdrop(this.kind);

  final String kind;

  @override
  void paint(Canvas canvas, Size size) {
    if (kind != 'checkerboard') {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = kind == 'black' ? Colors.black : Colors.white,
      );
      return;
    }
    const step = 24.0;
    for (var row = 0; row * step < size.height; row++) {
      for (var column = 0; column * step < size.width; column++) {
        canvas.drawRect(
          Rect.fromLTWH(column * step, row * step, step, step),
          Paint()..color = (row + column).isEven ? Colors.black : Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FixtureBackdrop oldDelegate) => kind != oldDelegate.kind;
}

class _SyntheticWebPage extends StatefulWidget {
  const _SyntheticWebPage();

  @override
  State<_SyntheticWebPage> createState() => _SyntheticWebPageState();
}

class _SyntheticWebPageState extends State<_SyntheticWebPage> {
  static const markdown =
      '# 合成文档 Synthetic document\n\n'
      '[示例链接 example.com](https://example.com/synthetic-readability)\n\n'
      '| 测试列 | Generated value |\n| --- | --- |\n'
      '| 示例内容 | Readable table controls |\n\n'
      '```javascript\nconst generatedFixture = true;\n```\n\n'
      '<div><p>生成的 HTML 区块。</p></div>\n';

  late final Future<Uri> entry = MilkdownAssetServer.ensureSharedStarted().then(
    (server) => server.entryUri(),
  );
  InAppWebViewController? controller;
  bool ready = false;
  String status = '正在准备生成的文档…';

  String css(Color color) =>
      'rgba(${(color.r * 255).round()},${(color.g * 255).round()},'
      '${(color.b * 255).round()},${color.a})';

  Map<String, dynamic> themePayload() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.extension<AppStyleTheme>()!;
    final popup = style.resolveSurface(theme, role: SurfaceRole.modal);
    return ThemePalettePayload(
      mode: theme.brightness == Brightness.dark ? 'dark' : 'light',
      colors: {
        'primary': css(scheme.primary),
        'onPrimary': css(scheme.onPrimary),
        'surface': 'transparent',
        'background': 'transparent',
        'onSurface': css(scheme.onSurface),
        'onBackground': css(scheme.onSurface),
        'outline': css(scheme.outline),
        'error': css(scheme.error),
        'onError': css(scheme.onError),
        'shadow': 'rgba(0,0,0,0.16)',
        'overlaySurface': css(popup.surface),
        'overlayOnSurface': css(popup.onSurface),
        'overlayOnSurfaceVariant': css(popup.onSurfaceVariant),
        'overlayPrimary': css(popup.primary),
        'overlayOnPrimary': css(popup.onPrimary),
        'overlayPrimaryContainer': css(popup.primaryContainer),
        'overlayOnPrimaryContainer': css(popup.onPrimaryContainer),
        'overlayError': css(popup.error),
        'overlayOutline': css(popup.outline),
        'overlayIcon': css(popup.icon),
        'overlayMutedIcon': css(popup.mutedIcon),
      },
      bodyFont: 'sans-serif',
      monoFont: 'monospace',
      sizePx: 16 * MediaQuery.textScalerOf(context).scale(1),
      lineHeight: 1.6,
    ).toJson();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) unawaited(_sendTheme());
  }

  Future<void> _sendTheme() async {
    await controller?.evaluateJavascript(
      source:
          '''
      window.__USHIO_BRIDGE__?.onFlutterMessage({type:'update_theme',
        payload:${jsonEncode(themePayload())}});
    ''',
    );
  }

  Future<void> _boot(InAppWebViewController webView) async {
    try {
      final result = await webView.callAsyncJavaScript(
        functionBody:
            '''
        const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
        for (let attempt=0;attempt<600;attempt++) {
          if (window.__USHIO_BRIDGE__?.onFlutterMessage) break;
          await wait(25);
        }
        const bridge=window.__USHIO_BRIDGE__;
        if (!bridge) throw new Error('Synthetic editor bridge unavailable');
        bridge.onFlutterMessage({type:'update_theme',payload:${jsonEncode(themePayload())}});
        bridge.onFlutterMessage({type:'init_doc',payload:{
          markdown:${jsonEncode(markdown)},readOnly:false,baseDirectory:''}});
        for (let attempt=0;attempt<600;attempt++) {
          if(document.querySelector('.ProseMirror a[href]')) return true;
          await wait(25);
        }
        throw new Error('Synthetic document not ready');
      ''',
      );
      if (result?.error != null) throw StateError('${result!.error}');
      if (!mounted) return;
      setState(() {
        ready = true;
        status = '生成的文档已就绪；链接仅用于检查，不会打开外部页面。';
      });
    } catch (error) {
      if (mounted) setState(() => status = '合成 Web 检查失败：$error');
    }
  }

  Future<void> _openOverlay(bool table) async {
    final result = await controller?.callAsyncJavaScript(
      functionBody: table
          ? '''
          const cell=document.querySelector('.ProseMirror td');
          if(!cell) throw new Error('Synthetic table unavailable');
          cell.scrollIntoView({block:'center'});
          cell.dispatchEvent(new MouseEvent('click',{bubbles:true}));
          await new Promise(resolve=>setTimeout(resolve,150));
          const button=document.querySelector('.ushio-table-fab');
          if(!button) throw new Error('Table menu unavailable');
          button.click();
          return true;
        '''
          : '''
          const link=document.querySelector('.ProseMirror a[href]');
          if(!link) throw new Error('Synthetic link unavailable');
          link.scrollIntoView({block:'center'});
          link.dispatchEvent(new MouseEvent('mouseover',{bubbles:true}));
          return true;
        ''',
    );
    if (result?.error != null && mounted) {
      setState(() => status = '合成浮层检查失败：${result!.error}');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.18,
        ),
        child: SingleChildScrollView(
          child: AppSurface(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: ready ? () => _openOverlay(false) : null,
                      child: const Text('链接浮层'),
                    ),
                    TextButton(
                      onPressed: ready ? () => _openOverlay(true) : null,
                      child: const Text('表格操作面板'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<Uri>(
          future: entry,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppSurface(child: Text('资源准备失败：${snapshot.error}'));
            }
            final uri = snapshot.data;
            if (uri == null) return const CircularProgressIndicator();
            return InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(uri.toString())),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
              ),
              onWebViewCreated: (value) => controller = value,
              onLoadStop: (value, _) => _boot(value),
              shouldOverrideUrlLoading: (_, action) async =>
                  action.request.url?.host == 'localhost' ||
                      action.request.url?.host == '127.0.0.1'
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL,
            );
          },
        ),
      ),
    ],
  );
}
