import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import '../models/milkdown_bridge.dart';
import '../services/milkdown_asset_server.dart';
import '../services/my_files_service.dart';
import '../utils/constants.dart';
import '../utils/debug_log.dart';
import '../utils/app_style.dart';

typedef MilkdownBridgeMessageHandler = void Function(Map<String, dynamic> msg);
typedef MilkdownCheckboxToggleHandler = void Function(int index, bool value);

const _defaultBodyFont = 'Noto Sans SC';
const _defaultMonoFont = 'JetBrains Mono';
const _defaultFontSize = 16.0;
const _defaultLineHeight = 1.6;

/// 内容安全工具类
class _ContentSanitizer {
  /// 危险的 HTML 标签
  static final RegExp _dangerousTags = RegExp(
    r'<\s*(script|iframe|object|embed|form|input|button|meta|link|style|base)[^>]*>',
    caseSensitive: false,
  );

  /// 危险的事件处理器
  static final RegExp _dangerousAttributes = RegExp(
    r'''\s(on\w+)\s*=\s*['"][^'"]*['"]''',
    caseSensitive: false,
  );

  /// javascript: 协议
  static final RegExp _javascriptProtocol = RegExp(
    r'''(href|src|action)\s*=\s*['"]?\s*javascript:''',
    caseSensitive: false,
  );

  /// data: 协议中的潜在危险内容
  static final RegExp _dangerousDataUri = RegExp(
    r'data\s*:\s*(?!image/(png|jpe?g|gif|webp|svg\+xml|bmp|ico))[a-z0-9+.-]+',
    caseSensitive: false,
  );

  /// 清理 Markdown 内容中的潜在 XSS 向量
  ///
  /// 注意：Milkdown 本身已有隔离机制，这是额外的防护层
  static String sanitizeMarkdown(String markdown) {
    var sanitized = markdown;

    // 移除危险标签
    sanitized = sanitized.replaceAll(_dangerousTags, '');

    // 移除事件处理器
    sanitized = sanitized.replaceAllMapped(_dangerousAttributes, (match) => '');

    // 移除 javascript: 协议
    sanitized = sanitized.replaceAllMapped(
      _javascriptProtocol,
      (match) => match
          .group(0)!
          .replaceFirst(RegExp(r'javascript:', caseSensitive: false), '#'),
    );

    return sanitized;
  }

  /// 清理 URL，阻止危险协议
  static String sanitizeUrl(String url) {
    final trimmed = url.trim();

    // 允许的协议
    const allowedProtocols = [
      'http://',
      'https://',
      'ftp://',
      'mailto:',
      'tel:',
    ];

    // 检查是否以允许的协议开头
    for (final proto in allowedProtocols) {
      if (trimmed.toLowerCase().startsWith(proto)) {
        return trimmed;
      }
    }

    // 检查是否是相对路径或锚点
    if (trimmed.startsWith('/') ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('?')) {
      return trimmed;
    }

    // 检查是否是 data: URI（仅允许图片）
    if (trimmed.toLowerCase().startsWith('data:image/')) {
      return trimmed;
    }

    // 阻止 javascript:, vbscript: 等危险协议
    if (trimmed.toLowerCase().startsWith('javascript:') ||
        trimmed.toLowerCase().startsWith('vbscript:') ||
        trimmed.toLowerCase().startsWith('data:text/html')) {
      return '#blocked';
    }

    // 默认当作相对路径
    return trimmed;
  }

  /// 检查内容是否包含潜在的恶意代码
  static bool containsDangerousContent(String content) {
    return _dangerousTags.hasMatch(content) ||
        _dangerousAttributes.hasMatch(content) ||
        _javascriptProtocol.hasMatch(content);
  }
}

// Global warm server instance and mutex
MilkdownAssetServer? _warmServer;
bool _isWarmingUp = false;
Completer<void>? _warmupCompleter;
const _localhostPortStart = 8080;
const _localhostPortAttempts = 8;
const _serverStartTimeout = Duration(seconds: 3);

/// Starts a local Milkdown asset server, falling back to adjacent ports.
///
/// 端口占用时逐个回退，并保留超时兜底，避免编辑器永远停留在“正在初始化编辑器...”。
Future<MilkdownAssetServer?> _startMilkdownServer({
  String documentRoot = 'assets/milkdown_web',
}) async {
  for (var i = 0; i < _localhostPortAttempts; i++) {
    final port = _localhostPortStart + i;
    final server = MilkdownAssetServer(port: port, documentRoot: documentRoot);
    try {
      appDebugLog('[SERVER] Trying port $port...');
      await server.start().timeout(_serverStartTimeout);
      appDebugLog('[SERVER] Server started on port $port');
      return server;
    } catch (e) {
      appDebugLog('[SERVER] Port $port unavailable: $e');
    }
  }
  appDebugLog('[SERVER] All fallback ports failed');
  return null;
}

/// 编辑器页面的运行时 URL（含缓存键）。
///
/// index.html 打包在 APK 内，只有版本升级才会变，所以用版本号做查询参数：WebView 的
/// HTTP 缓存与 V8 代码缓存因此能跨「打开文档」复用。此前每次都用微秒时间戳，等于每
/// 打开一篇就把 ~2.8MB 资源重新拉取、重新解析、重新编译一遍。
/// 调试构建按进程取一个时间戳：既能避开旧缓存，又让预热视图与编辑器命中同一 URL。
final String _debugUrlStamp = DateTime.now().microsecondsSinceEpoch.toString();

String buildMilkdownRuntimeUrl(MilkdownAssetServer server) {
  final stamp = kDebugMode ? _debugUrlStamp : AppConstants.appVersion;
  return 'http://localhost:${server.port}/index.html?v=$stamp';
}

/// 取得（必要时先拉起）资源服务器并返回编辑器 URL。
Future<String?> milkdownRuntimeUrl() async {
  await warmUpMilkdownWebAssets();
  final server = _warmServer;
  if (server == null) return null;
  return buildMilkdownRuntimeUrl(server);
}

Future<void> warmUpMilkdownWebAssets() async {
  appDebugLog('[WARMUP] warmUpMilkdownWebAssets() called');

  // Return immediately if server is already running
  if (_warmServer != null) {
    appDebugLog('[WARMUP] Server already running, returning immediately');
    return;
  }

  // If warmup is in progress, wait for it to complete
  if (_isWarmingUp && _warmupCompleter != null) {
    appDebugLog('[WARMUP] Warmup in progress, waiting for completion');
    try {
      await _warmupCompleter!.future.timeout(const Duration(seconds: 3));
      appDebugLog('[WARMUP] Wait completed');
      if (_warmServer != null) return;
    } on TimeoutException {
      appDebugLog('[WARMUP] Existing warmup timed out, starting fallback');
    }
  }

  _isWarmingUp = true;
  final completer = Completer<void>();
  _warmupCompleter = completer;
  appDebugLog('[WARMUP] Starting server...');

  try {
    final stopwatch = Stopwatch()..start();
    _warmServer = await _startMilkdownServer();
    if (_warmServer != null) {
      stopwatch.stop();
      appDebugLog(
        '[WARMUP] Server started in ${stopwatch.elapsedMilliseconds}ms',
      );
      unawaited(_warmServer!.preloadEntryAssets());
    }
  } catch (e) {
    appDebugLog('[WARMUP] FAILED: $e');
  } finally {
    if (identical(_warmupCompleter, completer)) {
      _isWarmingUp = false;
      _warmupCompleter = null;
    }
    completer.complete();
    appDebugLog('[WARMUP] Cleanup done');
  }
}

class MilkdownWebViewController {
  _MilkdownWebViewEditorState? _state;
  InAppWebViewController? _webViewController;

  void _attach(_MilkdownWebViewEditorState state) {
    _state = state;
  }

  void _detach(_MilkdownWebViewEditorState state) {
    if (identical(_state, state)) {
      _state = null;
      _webViewController = null;
    }
  }

  void _attachWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  void suppressNextReload() {
    _state?._suppressReloadToken = DateTime.now();
  }

  Future<void> setMarkdown(String markdown) async {
    await _state?._sendInitDoc(markdownOverride: markdown);
  }

  Future<void> updateTheme(ThemePalettePayload payload) async {
    await _state?._sendTheme(payloadOverride: payload);
  }

  Future<void> execCmd(String cmd, {Map<String, dynamic>? args}) async {
    await _state?._sendExecCmd(cmd, args: args);
  }

  Future<void> undo() => execCmd('undo');
  Future<void> redo() => execCmd('redo');
  Future<void> forceCaretIntoView() => execCmd('scroll_caret_into_view');

  /// 同步 Flutter 侧的遮挡信息，WebView 用它换算光标可用的可视区。
  Future<void> setKeyboardMetrics({
    required double keyboardInset,
    required double toolbarHeight,
    required double headerHeight,
  }) async {
    await _state?._sendKeyboardMetrics(
      keyboardInset: keyboardInset,
      toolbarHeight: toolbarHeight,
      headerHeight: headerHeight,
    );
  }
  Future<void> toggleBold() => execCmd('toggle_bold');
  Future<void> toggleItalic() => execCmd('toggle_italic');
  Future<void> insertTable() => execCmd('insert_table');
  Future<void> insertHorizontalRule() => execCmd('insert_hr');
  Future<void> focusEditor() => execCmd('focus_editor');
  Future<void> clearFocus() async {
    await _webViewController?.clearFocus();
  }

  Future<void> toggleStrikethrough() => execCmd('toggle_strikethrough');
  Future<void> toggleHighlight() => execCmd('toggle_highlight');
  Future<void> toggleInlineCode() => execCmd('toggle_inline_code');
  Future<void> setHeading(int level) =>
      execCmd('set_heading', args: {'level': level});
  Future<void> toggleBlockquote() => execCmd('toggle_blockquote');
  Future<void> toggleBulletList() => execCmd('toggle_bullet_list');
  Future<void> toggleOrderedList() => execCmd('toggle_ordered_list');
  Future<void> insertCodeBlock({String? language}) => execCmd(
    'insert_code_block',
    args: {if (language != null) 'language': language},
  );
  Future<void> insertMathBlock() => execCmd('insert_math_block');
  Future<void> toggleLink({String href = 'https://', String? title}) => execCmd(
    'toggle_link',
    args: {'href': href, if (title != null) 'title': title},
  );
  Future<void> goToNextTableCell() => execCmd('table_next_cell');
  Future<void> goToPrevTableCell() => execCmd('table_prev_cell');
  Future<void> addTableRowBefore() => execCmd('table_add_row_before');
  Future<void> addTableRowAfter() => execCmd('table_add_row_after');
  Future<void> addTableColumnBefore() => execCmd('table_add_col_before');
  Future<void> addTableColumnAfter() => execCmd('table_add_col_after');
  Future<void> deleteSelectedTableCells() => execCmd('table_delete_selected');
  Future<void> deleteCurrentTableRow() => execCmd('table_delete_row');
  Future<void> deleteCurrentTableColumn() => execCmd('table_delete_col');
  Future<void> insertImage({required String src, String? alt}) =>
      execCmd('insert_image', args: {'src': src, if (alt != null) 'alt': alt});
  Future<void> insertEmoji({String emoji = '😀'}) =>
      execCmd('insert_emoji', args: {'emoji': emoji});

  Future<void> scrollToHeading({
    required int headingIndex,
    required int lineNumber,
    required String headingText,
    double topOffset = 32.0,
  }) async {
    await execCmd(
      'toc_jump',
      args: {
        'headingIndex': headingIndex,
        'lineNumber': lineNumber,
        'headingText': headingText,
        'topOffset': topOffset,
      },
    );
  }

  Future<Uint8List?> captureScreenshot() async {
    try {
      return await _webViewController?.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> captureFullPageScreenshot({
    int maxShots = 30,
    Duration settleDelay = const Duration(milliseconds: 80),
  }) async {
    final c = _webViewController;
    if (c == null) return null;

    try {
      final originalYRaw = await c.evaluateJavascript(
        source: 'window.scrollY || 0',
      );
      final vhRaw = await c.evaluateJavascript(
        source: 'window.innerHeight || 0',
      );
      final shRaw = await c.evaluateJavascript(
        source:
            'Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) || 0',
      );

      final originalY =
          (double.tryParse(originalYRaw?.toString() ?? '0') ?? 0.0).clamp(
            0.0,
            double.infinity,
          );
      final viewportHeightCss =
          (double.tryParse(vhRaw?.toString() ?? '0') ?? 0.0).clamp(
            1.0,
            double.infinity,
          );
      final pageHeightCss = (double.tryParse(shRaw?.toString() ?? '0') ?? 0.0)
          .clamp(1.0, double.infinity);

      final steps = <double>[];
      for (double y = 0; y < pageHeightCss; y += viewportHeightCss) {
        steps.add(y);
        if (steps.length >= maxShots) break;
      }

      final captures = <({double yCss, Uint8List png})>[];
      for (final y in steps) {
        await c.evaluateJavascript(source: 'window.scrollTo(0, $y)');
        await Future.delayed(settleDelay);
        final png = await c.takeScreenshot();
        if (png == null) continue;
        captures.add((yCss: y, png: png));
      }

      await c.evaluateJavascript(source: 'window.scrollTo(0, $originalY)');

      if (captures.isEmpty) return null;

      final first = await _decodePng(captures.first.png);
      final scale = first.height / viewportHeightCss;
      final targetWidth = first.width;
      final targetHeight = (pageHeightCss * scale).ceil();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      for (final cap in captures) {
        final img = await _decodePng(cap.png);
        final dy = (cap.yCss * scale).roundToDouble();
        canvas.drawImage(img, ui.Offset(0, dy), ui.Paint());
      }

      final picture = recorder.endRecording();
      final stitched = await picture.toImage(targetWidth, targetHeight);
      final bytes = await stitched.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _decodePng(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class MilkdownWebViewEditor extends StatefulWidget {
  final String initialMarkdown;
  final bool readOnly;
  final ValueChanged<String>? onContentChange;
  final MilkdownBridgeMessageHandler? onBridgeMessage;
  final ValueChanged<OnImageErrorPayload>? onImageError;
  final ValueChanged<OnImageClickPayload>? onImageClick;
  final ValueChanged<OnOutlineUpdatePayload>? onOutlineUpdate;
  final ValueChanged<OnLinkClickPayload>? onLinkClick;
  final MilkdownCheckboxToggleHandler? onCheckboxToggle;
  final ValueChanged<OnUploadImagesRequestPayload>? onUploadImagesRequest;
  final void Function(bool canUndo, bool canRedo)? onHistoryState;
  final bool enableInsertImagePicker;
  final bool enableInsertImageUrl;
  final VoidCallback? onLoadFinished;
  final void Function(double progress)? onRenderProgress;
  final VoidCallback? onRenderTimeout;
  final VoidCallback? onRenderTimeoutExit;
  final MilkdownWebViewController? controller;
  final String? bodyFont;
  final String? monoFont;
  final double? fontSize;
  final double? lineHeight;
  final double? letterSpacing;
  final double? paragraphSpacing;
  final String? baseDirectory;
  final String? codeBlockTheme;
  final Color? textColor;

  const MilkdownWebViewEditor({
    super.key,
    required this.initialMarkdown,
    this.readOnly = false,
    this.onContentChange,
    this.onBridgeMessage,
    this.onImageError,
    this.onImageClick,
    this.onOutlineUpdate,
    this.onLinkClick,
    this.onCheckboxToggle,
    this.onUploadImagesRequest,
    this.onHistoryState,
    this.enableInsertImagePicker = true,
    this.enableInsertImageUrl = true,
    this.onLoadFinished,
    this.onRenderProgress,
    this.onRenderTimeout,
    this.onRenderTimeoutExit,
    this.controller,
    this.bodyFont,
    this.monoFont,
    this.fontSize,
    this.lineHeight,
    this.letterSpacing,
    this.paragraphSpacing,
    this.baseDirectory,
    this.codeBlockTheme,
    this.textColor,
  });

  @override
  State<MilkdownWebViewEditor> createState() => _MilkdownWebViewEditorState();
}

class _MilkdownWebViewEditorState extends State<MilkdownWebViewEditor> {
  static const _documentRoot = 'assets/milkdown_web';
  static const int _maxUploadPersistRetries = 2;
  static const String _localFileScheme = 'ushio-local-file';

  String _buildRuntimeUrl(MilkdownAssetServer server) =>
      buildMilkdownRuntimeUrl(server);

  InAppWebViewController? _controller;
  MilkdownAssetServer? _localhostServer;
  String? _initialUrl;
  String? _lastThemeSignature;
  String? _lastSyncedMarkdown;
  bool _isServerStarting = false;
  bool _didFinishFirstRender = false;

  /// 首屏遮罩是否还留在树上（淡出动画播完才摘）。
  bool _overlayMounted = true;
  Timer? _firstRenderTimer;
  bool _renderTimedOut = false;
  double _renderProgress = 0;
  // 使用带时间戳的 token 机制，避免布尔标志因时序问题被错误消费
  static const _suppressTtlMs = 2000; // 2 秒有效期
  DateTime? _suppressReloadToken;
  bool _isDisposed = false;

  /// 页面内 `window.__USHIO_BRIDGE__` 就绪信号（由 JS 主动回推）。
  final Completer<void> _bridgeReady = Completer<void>();

  /// 打开文档的分段计时基准，输出见 `openTrace`。
  final Stopwatch _openTraceWatch = Stopwatch();

  /// Log errors only (minimal logging for production)
  void _logError(String message) {
    appDebugLog(message);
  }

  void _resetFirstRenderState() {
    _firstRenderTimer?.cancel();
    _didFinishFirstRender = false;
    _overlayMounted = true;
    _renderTimedOut = false;
    _renderProgress = 0;
  }

  void _startFirstRenderTimer() {
    _firstRenderTimer?.cancel();
    _firstRenderTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _isDisposed || _didFinishFirstRender) return;
      setState(() => _renderTimedOut = true);
      widget.onRenderTimeout?.call();
    });
  }

  /// 安全检查：验证请求的文件路径是否在允许的目录范围内
  /// 防止路径遍历攻击，避免访问工作区外的敏感文件
  Future<bool> _isPathAllowed(String filePath) async {
    try {
      // 规范化路径，解析 ..、. 和符号链接
      final normalizedPath = File(filePath).absolute.path;

      // 允许的根目录列表
      final allowedRoots = <String>[];

      // 1. 工作区目录（如果配置了）
      if (widget.baseDirectory != null && widget.baseDirectory!.isNotEmpty) {
        final baseDir = Directory(widget.baseDirectory!).absolute.path;
        allowedRoots.add(baseDir);
      }

      // 2. 应用私有目录（用于缓存等）
      if (Platform.isAndroid || Platform.isIOS) {
        // 获取应用私有目录
        final appDir = Directory.systemTemp.absolute.path;
        allowedRoots.add(appDir);
      }

      // 3. 外部存储目录（Android）
      if (Platform.isAndroid) {
        final externalDir = Directory('/storage/emulated/0').absolute.path;
        allowedRoots.add(externalDir);
        // 添加 /sdcard 路径（通常是 /storage/emulated/0 的符号链接）
        allowedRoots.add('/sdcard');
      }

      // 检查规范化后的路径是否在允许的根目录下
      for (final root in allowedRoots) {
        if (normalizedPath.startsWith(root)) {
          return true;
        }
      }

      _logError('[Security] Path access denied: $filePath');
      return false;
    } catch (e) {
      _logError('[Security] Path validation error: $e');
      return false;
    }
  }

  Future<CustomSchemeResponse?> _serveLocalFileRequest(Uri uri) async {
    if (uri.scheme != _localFileScheme) return null;
    final requestedPathRaw = uri.queryParameters['path'] ?? '';
    if (requestedPathRaw.isEmpty) {
      return CustomSchemeResponse(
        data: Uint8List(0),
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
      );
    }

    final requestedPath = requestedPathRaw.trim();

    // 安全检查：验证路径是否在允许范围内
    final isAllowed = await _isPathAllowed(requestedPath);
    if (!isAllowed) {
      return CustomSchemeResponse(
        data: Uint8List(0),
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
      );
    }

    final file = File(requestedPath);
    final fileExists = await file.exists();
    if (!fileExists) {
      return CustomSchemeResponse(
        data: Uint8List(0),
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final mime = lookupMimeType(requestedPath) ?? 'application/octet-stream';
      return CustomSchemeResponse(
        data: bytes,
        contentType: mime,
        contentEncoding: 'binary',
      );
    } catch (e) {
      _logError('[LocalFile] Error reading file: $e');
      return CustomSchemeResponse(
        data: Uint8List(0),
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    appDebugLog(
      '[WEBVIEW] initState called, initialMarkdown length: ${widget.initialMarkdown.length}',
    );
    _lastSyncedMarkdown = widget.initialMarkdown;
    _openTraceWatch.start();
    openTrace('webview widget created');
    // 预热服务器已就绪时同步取用：否则首帧只能画「正在初始化编辑器…」骨架，
    // 等一次异步回调 + setState 才创建 WebView，白白多花一到数帧。
    final warm = _warmServer;
    if (warm != null && !_isWarmingUp) {
      _localhostServer = warm;
      _initialUrl = _buildRuntimeUrl(warm);
      appDebugLog('[WEBVIEW] warm server taken synchronously in initState');
    } else {
      _startLocalhostServer();
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
  }

  Future<void> _startLocalhostServer() async {
    appDebugLog('[WEBVIEW] _startLocalhostServer called');
    if (_isServerStarting || _localhostServer != null || _isDisposed) {
      appDebugLog(
        '[WEBVIEW] Server already starting/started or disposed, skipping',
      );
      return;
    }
    _isServerStarting = true;

    try {
      final stopwatch = Stopwatch()..start();

      // If warmup is in progress, wait for it to complete instead of
      // creating a competing server on the same port.
      if (_isWarmingUp && _warmupCompleter != null) {
        appDebugLog('[WEBVIEW] Warmup in progress, waiting for completion...');
        try {
          await _warmupCompleter!.future.timeout(const Duration(seconds: 3));
          appDebugLog(
            '[WEBVIEW] Warmup completed, checking server availability',
          );
        } on TimeoutException {
          appDebugLog('[WEBVIEW] Warmup wait timed out, starting own server');
        }
      }

      // Check if warmup server is available and reuse it
      if (_warmServer != null) {
        appDebugLog('[WEBVIEW] Reusing existing warmup server');
        if (!mounted || _isDisposed) {
          appDebugLog('[WEBVIEW] Widget unmounted or disposed');
          return;
        }
        setState(() {
          _localhostServer = _warmServer;
          _initialUrl = _buildRuntimeUrl(_warmServer!);
        });
        stopwatch.stop();
        appDebugLog(
          '[WEBVIEW] Warmup server reused in ${stopwatch.elapsedMilliseconds}ms, _initialUrl: $_initialUrl',
        );
        return;
      }

      appDebugLog(
        '[WEBVIEW] No warmup server, creating new MilkdownAssetServer...',
      );
      final server = await _startMilkdownServer(documentRoot: _documentRoot);
      if (server == null) {
        appDebugLog('[WEBVIEW] No server could be started');
        if (!mounted || _isDisposed) return;
        setState(() {
          _initialUrl = '';
        });
        return;
      }
      stopwatch.stop();
      appDebugLog(
        '[WEBVIEW] Server started in ${stopwatch.elapsedMilliseconds}ms',
      );
      if (!mounted || _isDisposed) {
        appDebugLog('[WEBVIEW] Widget unmounted or disposed, closing server');
        await server.close();
        return;
      }
      setState(() {
        _localhostServer = server;
        _initialUrl = _buildRuntimeUrl(server);
      });
      appDebugLog('[WEBVIEW] Server state updated, _initialUrl: $_initialUrl');
    } catch (e) {
      appDebugLog('[WEBVIEW] FAILED to start server: $e');
      if (!mounted || _isDisposed) return;
      setState(() {
        _initialUrl = '';
      });
    } finally {
      _isServerStarting = false;
      appDebugLog('[WEBVIEW] _startLocalhostServer done');
    }
  }

  /// 等待页面内的 `window.__USHIO_BRIDGE__` 就绪。
  ///
  /// JS 在定义 bridge 后立刻回推 on_bridge_ready，所以正常路径只有一次平台通道往返；
  /// 固定 100ms 步长的轮询会让首帧白等最多 100ms，这里只作为收不到通知（如 bfcache
  /// 恢复、JS 未执行）时的兜底。
  Future<bool> _waitForBridgeReady(InAppWebViewController controller) async {
    try {
      await _bridgeReady.future.timeout(const Duration(milliseconds: 1500));
      return true;
    } on TimeoutException {
      appDebugLog('[WEBVIEW] bridge push timed out, polling as fallback');
    }
    for (var attempts = 0; attempts < 100; attempts++) {
      try {
        final ready = await controller.evaluateJavascript(
          source:
              '!!(window.__USHIO_BRIDGE__ && window.__USHIO_BRIDGE__.onFlutterMessage)',
        );
        if (ready == true) return true;
      } catch (_) {
        // 页面仍在切文档时会抛异常，继续等
      }
      await Future.delayed(const Duration(milliseconds: 25));
    }
    return false;
  }

  ThemePalettePayload _buildThemePayload() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    final bodyFont = widget.bodyFont ?? _defaultBodyFont;
    final monoFont = widget.monoFont ?? _defaultMonoFont;
    final fontSize = widget.fontSize ?? _defaultFontSize;
    final lineHeight = widget.lineHeight ?? _defaultLineHeight;
    final letterSpacing = widget.letterSpacing ?? 0.0;
    final paragraphSpacing = widget.paragraphSpacing ?? 8.0;

    // Get border radius from theme or use default
    const borderRadius = 12.0;

    final textColor = widget.textColor ?? colorScheme.onSurface;
    final shadowOpacity = brightness == Brightness.dark ? 0.12 : 0.08;

    return ThemePalettePayload(
      mode: mode,
      colors: {
        'primary': _toCssHex(colorScheme.primary),
        'onPrimary': _toCssHex(colorScheme.onPrimary),
        'secondary': _toCssHex(colorScheme.secondary),
        'onSecondary': _toCssHex(colorScheme.onSecondary),
        'surface': _toCssHex(
          theme.extension<AppStyleTheme>()!.useLiquidGlass
              ? colorScheme.surface.withValues(alpha: 0)
              : colorScheme.surface,
        ),
        'onSurface': _toCssHex(textColor),
        'background': _toCssHex(
          theme.extension<AppStyleTheme>()!.useLiquidGlass
              ? colorScheme.surface.withValues(alpha: 0)
              : colorScheme.surface,
        ),
        'onBackground': _toCssHex(textColor),
        'error': _toCssHex(colorScheme.error),
        'onError': _toCssHex(colorScheme.onError),
        'outline': _toCssHex(colorScheme.outline),
        'shadow': _toCssRgba(colorScheme.shadow),
      },
      bodyFont: bodyFont,
      monoFont: monoFont,
      sizePx: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      paragraphSpacing: paragraphSpacing,
      borderRadius: borderRadius,
      shadowOpacity: shadowOpacity,
      codeBlockTheme: widget.codeBlockTheme ?? 'auto',
    );
  }

  String _themeSignature() {
    final payload = _buildThemePayload();
    return jsonEncode(payload.toJson());
  }

  void _syncThemeIfNeeded() {
    if (_controller == null) return;
    final sig = _themeSignature();
    if (_lastThemeSignature != sig) {
      _sendTheme();
    }
  }

  Map<String, double> _lastKeyboardMetrics = const {};

  /// 键盘高度、悬浮工具栏与悬浮头部的高度只有 Flutter 侧知道。
  ///
  /// WebView 在 adjustNothing 下尺寸恒定，`window.visualViewport` 也报不出软键盘，
  /// JS 自己算出来的可视区会一路延伸到键盘以下，光标避让因此既不触发、触发时又
  /// 一次跳出很远。这三个数就是它唯一可信的遮挡来源。
  Future<void> _sendKeyboardMetrics({
    required double keyboardInset,
    required double toolbarHeight,
    required double headerHeight,
  }) async {
    final metrics = <String, double>{
      'keyboardInset': keyboardInset,
      'toolbarHeight': toolbarHeight,
      'headerHeight': headerHeight,
    };
    _lastKeyboardMetrics = metrics;
    await _sendExecCmd('set_keyboard_metrics', args: metrics);
  }

  /// 页面重新加载后 JS 侧的遮挡数据全丢了，按缓存补发一次。
  Future<void> _resendKeyboardMetrics() async {
    if (_lastKeyboardMetrics.isEmpty || _controller == null) return;
    await _sendExecCmd('set_keyboard_metrics', args: _lastKeyboardMetrics);
  }

  Future<void> _sendInitDoc({String? markdownOverride}) async {
    appDebugLog(
      '[WEBVIEW] _sendInitDoc called, markdownOverride: ${markdownOverride != null}',
    );
    var markdown = markdownOverride ?? widget.initialMarkdown;
    appDebugLog('[WEBVIEW] _sendInitDoc: markdown length = ${markdown.length}');

    _resetFirstRenderState();
    _startFirstRenderTimer();
    _lastSyncedMarkdown = markdown;
    final msg = BridgeEnvelope<InitDocPayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'init_doc',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: InitDocPayload(
        markdown: markdown,
        baseDirectory: widget.baseDirectory,
        readOnly: widget.readOnly,
      ),
    );
    appDebugLog('[WEBVIEW] _sendInitDoc: sending message...');
    await _sendMessage(msg.toJson((payload) => payload.toJson()));
    appDebugLog('[WEBVIEW] _sendInitDoc: done');
  }

  Future<void> _sendTheme({ThemePalettePayload? payloadOverride}) async {
    final payload = payloadOverride ?? _buildThemePayload();
    _lastThemeSignature = jsonEncode(payload.toJson());
    final msg = BridgeEnvelope<ThemePalettePayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'update_theme',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );
    await _sendMessage(msg.toJson((p) => p.toJson()));
  }

  Future<void> _sendExecCmd(String cmd, {Map<String, dynamic>? args}) async {
    final msg = BridgeEnvelope<ExecCmdPayload>(
      v: 1,
      source: 'flutter',
      target: 'web',
      type: 'exec_cmd',
      requestId: createBridgeRequestId(),
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: ExecCmdPayload(cmd: cmd, args: args),
    );
    await _sendMessage(msg.toJson((p) => p.toJson()));
  }

  Future<void> _sendUploadImagesResult(
    String requestId, {
    required List<Map<String, dynamic>> images,
    String? reason,
    String? failureReason,
    int? failureCount,
  }) async {
    await _sendExecCmd(
      'upload_images_result',
      args: {
        'requestId': requestId,
        'images': images,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (failureReason != null && failureReason.isNotEmpty)
          'failureReason': failureReason,
        if (failureCount != null && failureCount > 0)
          'failureCount': failureCount,
      },
    );
  }

  String _sanitizeFileName(String name) {
    final normalized = name.replaceAll('\\', '/');
    final lastSegment = normalized.split('/').last.trim();
    if (lastSegment.isEmpty) return 'upload_image';
    return lastSegment.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _extensionFromMimeType(String mimeType) {
    if (mimeType == 'image/jpeg' || mimeType == 'image/jpg') return '.jpg';
    if (mimeType == 'image/webp') return '.webp';
    if (mimeType == 'image/gif') return '.gif';
    if (mimeType == 'image/svg+xml') return '.svg';
    if (mimeType == 'image/bmp') return '.bmp';
    return '.png';
  }

  Future<File> _writeUniqueFile(
    Directory directory,
    String fileName,
    List<int> bytes,
  ) async {
    await directory.create(recursive: true);
    final dotIndex = fileName.lastIndexOf('.');
    final base = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex > 0 ? fileName.substring(dotIndex) : '';
    var candidate = File('${directory.path}${Platform.pathSeparator}$fileName');
    var count = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${directory.path}${Platform.pathSeparator}${base}_$count$ext',
      );
      count++;
    }
    await candidate.writeAsBytes(bytes, flush: true);
    return candidate;
  }

  Future<Map<String, dynamic>> _persistUploadedImage(
    UploadImageFilePayload file,
  ) async {
    final uriData = UriData.parse(file.dataUrl);
    final bytes = uriData.contentAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('empty_upload_image');
    }
    var fileName = _sanitizeFileName(file.name);
    if (!fileName.contains('.')) {
      final ext = _extensionFromMimeType(uriData.mimeType);
      fileName = '$fileName$ext';
    }
    if (widget.baseDirectory != null && widget.baseDirectory!.isNotEmpty) {
      final imagesDir = Directory(
        '${widget.baseDirectory}${Platform.pathSeparator}images',
      );
      final out = await _writeUniqueFile(imagesDir, fileName, bytes);
      final relativeName = out.path.split(Platform.pathSeparator).last;
      return {'src': 'images/$relativeName', 'alt': file.name};
    }
    final out = await _writeUniqueFile(Directory.systemTemp, fileName, bytes);
    return {'src': out.path, 'alt': file.name};
  }

  Future<Map<String, dynamic>> _persistUploadedImageWithRetry(
    UploadImageFilePayload file,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _maxUploadPersistRetries; attempt++) {
      try {
        return await _persistUploadedImage(file);
      } catch (e) {
        lastError = e;
        if (attempt >= _maxUploadPersistRetries) break;
        await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
      }
    }
    throw Exception('persist_image_retries_exhausted:$lastError');
  }

  Future<void> _handleUploadImagesRequest(
    OnUploadImagesRequestPayload payload,
  ) async {
    widget.onUploadImagesRequest?.call(payload);
    var failureCount = 0;
    String? failureReason;
    try {
      final images = <Map<String, dynamic>>[];
      for (final file in payload.files) {
        images.add(await _persistUploadedImageWithRetry(file));
      }
      await _sendUploadImagesResult(payload.requestId, images: images);
    } catch (e) {
      failureCount += 1;
      final errorText = e.toString();
      if (errorText.contains('empty_upload_image')) {
        failureReason = 'upload_empty_file';
      } else if (errorText.contains('FormatException')) {
        failureReason = 'upload_decode_failed';
      } else if (errorText.contains('FileSystemException')) {
        failureReason = 'upload_write_failed';
      } else if (errorText.contains('persist_image_retries_exhausted')) {
        failureReason = 'upload_persist_retries_exhausted';
      } else {
        failureReason = 'upload_failed';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片上传失败：$failureReason，可重试'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                _handleUploadImagesRequest(payload);
              },
            ),
          ),
        );
      }
      await _sendUploadImagesResult(
        payload.requestId,
        images: const [],
        reason: '$failureReason:$e',
        failureReason: failureReason,
        failureCount: failureCount,
      );
    }
  }

  String _sanitizeInsertImageAlt(String? alt) {
    if (alt == null) return '';
    return alt.replaceAll('\n', ' ').trim();
  }

  Future<Map<String, String>?> _showInsertImageUrlDialog() async {
    if (!mounted || !widget.enableInsertImageUrl) return null;
    final urlController = TextEditingController();
    final altController = TextEditingController();
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.link, color: context.appIconColor),
              const SizedBox(width: 12),
              const Text('插入图片链接'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '图片 URL',
                    hintText: 'https://example.com/image.png',
                    prefixIcon: const Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altController,
                  decoration: InputDecoration(
                    labelText: '替代文本（可选）',
                    hintText: '用于无障碍与图片说明',
                    prefixIcon: const Icon(Icons.image_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  Navigator.pop(context, {
                    'url': url,
                    'alt': _sanitizeInsertImageAlt(altController.text),
                  });
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('插入'),
            ),
          ],
        ),
      );
    } finally {
      urlController.dispose();
      altController.dispose();
    }
  }

  Future<Map<String, String>?> _pickInsertImageFromDevice() async {
    if (!widget.enableInsertImagePicker) return null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final imagePath = file.path ?? '';
    if (imagePath.isEmpty) return null;
    if (widget.baseDirectory != null && widget.baseDirectory!.isNotEmpty) {
      final documentPath =
          '${widget.baseDirectory}${Platform.pathSeparator}__milkdown_insert__.md';
      try {
        final myFilesService = MyFilesService();
        final relativePath = await myFilesService.copyImageToDocument(
          imagePath,
          documentPath,
        );
        return {'src': relativePath, 'alt': _sanitizeInsertImageAlt(file.name)};
      } catch (_) {
        // fall back to original path
      }
    }
    return {'src': imagePath, 'alt': _sanitizeInsertImageAlt(file.name)};
  }

  Future<String?> _chooseInsertImageSource() async {
    if (!mounted) return null;
    return await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('输入图片链接'),
              subtitle: const Text('使用网络图片 URL'),
              enabled: widget.enableInsertImageUrl,
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从设备选择'),
              subtitle: const Text('选择本地图片文件'),
              enabled: widget.enableInsertImagePicker,
              onTap: () => Navigator.pop(context, 'device'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInsertImageRequest(
    OnInsertImageRequestPayload payload,
  ) async {
    try {
      final source = await _chooseInsertImageSource();
      Map<String, String>? selected;
      if (source == 'url') {
        selected = await _showInsertImageUrlDialog();
      } else if (source == 'device') {
        selected = await _pickInsertImageFromDevice();
      }
      if (selected == null) {
        await _sendExecCmd(
          'upload_images_result',
          args: {
            'requestId': payload.requestId,
            'images': const [],
            'reason': 'insert_image_cancelled',
          },
        );
        return;
      }
      var src = selected['src']?.trim() ?? '';
      if (src.isEmpty) {
        await _sendExecCmd(
          'upload_images_result',
          args: {
            'requestId': payload.requestId,
            'images': const [],
            'reason': 'insert_image_invalid_src',
          },
        );
        return;
      }

      // URL 安全检查：阻止危险协议
      src = _ContentSanitizer.sanitizeUrl(src);

      await _sendExecCmd(
        'upload_images_result',
        args: {
          'requestId': payload.requestId,
          'images': [
            {'src': src, 'alt': _sanitizeInsertImageAlt(selected['alt'])},
          ],
        },
      );
    } catch (e) {
      await _sendExecCmd(
        'upload_images_result',
        args: {
          'requestId': payload.requestId,
          'images': const [],
          'reason': 'insert_image_failed:$e',
        },
      );
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> msg) async {
    final msgType = msg['type'] as String?;
    appDebugLog(
      '[WEBVIEW] _sendMessage: type=$msgType, _controller=${_controller != null}',
    );

    if (_controller == null) {
      appDebugLog('[WEBVIEW] _sendMessage: _controller is null, cannot send');
      return;
    }

    // 直接把 JSON 文本当 JS 对象字面量注入：JSON 是 JS 表达式的合法子集，省掉
    // 「再转义成字符串 + JS 端 JSON.parse」这一层，大文档的注入体积近乎减半。
    // U+2028/U+2029 在 JSON 字符串中合法，但会被老引擎当成行终止符，显式转义。
    final payload = jsonEncode(
      msg,
    ).replaceAll('\u2028', r'\u2028').replaceAll('\u2029', r'\u2029');

    try {
      final result = await _controller!.evaluateJavascript(
        source:
            '''
          (function() {
            if (!window.__USHIO_BRIDGE__) {
              console.error('[JS ERROR] __USHIO_BRIDGE__ not defined');
              return 'error: bridge not defined';
            }
            if (!window.__USHIO_BRIDGE__.onFlutterMessage) {
              console.error('[JS ERROR] onFlutterMessage not defined');
              return 'error: onFlutterMessage not defined';
            }
            window.__USHIO_BRIDGE__.onFlutterMessage($payload);
            return 'ok';
          })();
        ''',
      );
      appDebugLog('[WEBVIEW] _sendMessage result: $result');
    } catch (e) {
      appDebugLog('[WEBVIEW] _sendMessage ERROR: $e');
    }
  }

  Future<void> _handleBridgeArgs(List<dynamic> args) async {
    if (args.isEmpty || args.first is! Map) {
      appDebugLog('[WEBVIEW] Bridge: invalid message args: $args');
      return;
    }
    final map = Map<String, dynamic>.from(args.first as Map);
    final msgType = map['type'] as String?;
    if (msgType == 'on_bridge_ready' && !_bridgeReady.isCompleted) {
      _bridgeReady.complete();
    }
    appDebugLog('[WEBVIEW] Bridge message received: type=$msgType');

    widget.onBridgeMessage?.call(map);
    OnUploadImagesRequestPayload? uploadPayload;
    OnInsertImageRequestPayload? insertImagePayload;
    dispatchMilkdownBridgeMessage(
      map,
      onContentChange: (markdown) {
        _lastSyncedMarkdown = markdown;
        widget.onContentChange?.call(markdown);
      },
      onOutlineUpdate: widget.onOutlineUpdate,
      onLinkClick: widget.onLinkClick,
      onImageError: widget.onImageError,
      onImageClick: widget.onImageClick,
      onUploadImagesRequest: (payload) {
        uploadPayload = payload;
      },
      onInsertImageRequest: (payload) {
        insertImagePayload = payload;
      },
      onCheckboxToggle: widget.onCheckboxToggle,
      onHistoryState: (payload) {
        widget.onHistoryState?.call(payload.canUndo, payload.canRedo);
      },
      onCmdResult: (cmd, ok, reason) {
        if (!ok) {
          appDebugLog(
            'Milkdown exec_cmd failed: cmd=$cmd reason=${reason ?? 'unknown'}',
          );
          final isExpectedHistoryNoop =
              (cmd == 'undo' || cmd == 'redo') && reason == 'not_applicable';
          if (!isExpectedHistoryNoop &&
              mounted &&
              reason != null &&
              reason.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('编辑命令失败：$cmd（$reason）'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      onRenderComplete: () {
        appDebugLog(
          '[WEBVIEW] onRenderComplete received, _didFinishFirstRender: $_didFinishFirstRender',
        );
        _firstRenderTimer?.cancel();
        if (!_didFinishFirstRender) {
          _didFinishFirstRender = true;
          appDebugLog('[WEBVIEW] _didFinishFirstRender set to true');
          openTrace('first render done');
        }
        if (mounted) {
          setState(() {
            _renderTimedOut = false;
            _renderProgress = 1;
          });
        }
        widget.onLoadFinished?.call();
      },
      onRenderProgress: (progress) {
        if (mounted && !_didFinishFirstRender) {
          setState(() => _renderProgress = progress.clamp(0.0, 1.0));
        }
        widget.onRenderProgress?.call(progress);
      },
    );
    if (uploadPayload != null) {
      await _handleUploadImagesRequest(uploadPayload!);
    }
    if (insertImagePayload != null) {
      await _handleInsertImageRequest(insertImagePayload!);
    }
  }

  @override
  void didUpdateWidget(covariant MilkdownWebViewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final markdownChanged = oldWidget.initialMarkdown != widget.initialMarkdown;
    final baseChanged = oldWidget.baseDirectory != widget.baseDirectory;
    final readOnlyChanged = oldWidget.readOnly != widget.readOnly;
    if (markdownChanged || baseChanged || readOnlyChanged) {
      // 检查 suppress token 是否有效（未过期）
      final token = _suppressReloadToken;
      final tokenValid =
          token != null &&
          DateTime.now().difference(token).inMilliseconds < _suppressTtlMs;
      if (tokenValid && markdownChanged) {
        // Suppress reload for code_sanitized mode - just update the synced markdown
        // without reinitializing the WebView, preserving focus and input method state
        _lastSyncedMarkdown = widget.initialMarkdown;
        _suppressReloadToken = null;
      } else if (_lastSyncedMarkdown != widget.initialMarkdown ||
          baseChanged ||
          readOnlyChanged) {
        _sendInitDoc();
      }
    }
    if (oldWidget.bodyFont != widget.bodyFont ||
        oldWidget.monoFont != widget.monoFont ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.codeBlockTheme != widget.codeBlockTheme) {
      _sendTheme();
    }
    _syncThemeIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncThemeIfNeeded();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _firstRenderTimer?.cancel();
    widget.controller?._detach(this);
    final server = _localhostServer;
    _localhostServer = null;
    // Only close the server if it's NOT the warmup server (which is shared)
    // The warmup server should remain running for reuse by other instances
    if (server != null && !identical(server, _warmServer)) {
      appDebugLog('[WEBVIEW] Closing non-warmup server');
      server.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    appDebugLog(
      '[WEBVIEW] build() called - _initialUrl: ${_initialUrl == null ? "null" : (_initialUrl!.isEmpty ? "empty" : "set")}, _didFinishFirstRender: $_didFinishFirstRender',
    );

    if (_initialUrl == null) {
      appDebugLog(
        '[WEBVIEW] build(): showing loading skeleton (server not ready)',
      );
      return _buildLoadingSkeleton(context, '正在初始化编辑器...');
    }

    if (_initialUrl!.isEmpty) {
      appDebugLog('[WEBVIEW] build(): showing error (server failed)');
      return const Center(
        child: Text('Failed to start Milkdown localhost server'),
      );
    }

    appDebugLog('[WEBVIEW] build(): rendering InAppWebView');
    // Use a key based on the URL to force a fresh WebView instance for each document
    // This ensures JavaScript is re-executed and the bridge is properly initialized
    final webViewKey = ValueKey(_initialUrl);
    return Stack(
      children: [
        InAppWebView(
          key: webViewKey,
          initialUrlRequest: URLRequest(url: WebUri(_initialUrl!)),
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            // 安全设置：限制跨域访问，仅允许必要的本地文件访问
            allowFileAccessFromFileURLs:
                false, // 禁止从 file:// URL 访问其他 file:// URL
            allowUniversalAccessFromFileURLs: false, // 禁止从 file:// URL 进行通用访问
            allowFileAccess: true, // 允许访问本地文件（用于加载 HTML 资源）
            javaScriptEnabled: true,
            // 只读模式下允许系统上下文菜单（用于文本选择和复制）
            // 编辑模式下也允许系统菜单，由 JavaScript 层控制是否显示自定义菜单
            disableContextMenu: false,
            supportZoom: false,
            builtInZoomControls: false,
            displayZoomControls: false,
            cacheEnabled: true,
            resourceCustomSchemes: [_localFileScheme],
            // 额外的安全设置
            mixedContentMode:
                MixedContentMode.MIXED_CONTENT_NEVER_ALLOW, // 禁止混合内容
            allowsInlineMediaPlayback: true,
          ),
          onWebViewCreated: (controller) {
            appDebugLog('[WEBVIEW] onWebViewCreated called');
            openTrace('android platform view attached');
            _controller = controller;
            widget.controller?._attach(this);
            widget.controller?._attachWebViewController(controller);
            controller.addJavaScriptHandler(
              handlerName: 'bridge',
              callback: (args) async {
                await _handleBridgeArgs(args);
                return {'ok': true};
              },
            );
            // 不做 clearCache：每次新建的 InAppWebView 都是全新文档与全新 JS 上下文，
            // JS 本就会重新执行；清掉的是整个 WebView 缓存，代价是每次都重取、重编译
            // 这份 ~2.8MB 资源。
            appDebugLog('[WEBVIEW] onWebViewCreated done');
          },
          onLoadStop: (controller, _) async {
            appDebugLog('[WEBVIEW] onLoadStop called');
            final bridgeReady = await _waitForBridgeReady(controller);
            openTrace('page loaded + bridge ready (ready=$bridgeReady)');

            // If bridge not ready, force a reload to re-execute JavaScript
            // This handles the case where WebView uses bfcache and doesn't re-run JS
            if (!bridgeReady) {
              appDebugLog('[WEBVIEW] JS bridge NOT ready, forcing reload...');
              try {
                // Use either localhostServer or warmServer for the URL
                final server = _localhostServer ?? _warmServer;
                if (server == null) {
                  appDebugLog('[WEBVIEW] No server available for reload');
                  return;
                }
                // Add a new timestamp to force cache bypass
                final newUrl = _buildRuntimeUrl(server);
                await controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(newUrl)),
                );
                appDebugLog('[WEBVIEW] Reload triggered with new URL: $newUrl');
                return; // onLoadStop will be called again after reload
              } catch (e) {
                appDebugLog('[WEBVIEW] Reload failed: $e');
                return;
              }
            }

            // 纯诊断信息：release 下省掉两次 Dart→JS 往返。
            if (kDebugMode) {
              try {
                final runtimeTag = await controller.evaluateJavascript(
                  source: 'window.__USHIO_RUNTIME_TAG || "missing_runtime_tag"',
                );
                appDebugLog('[MilkdownRuntimeTag] $runtimeTag');
              } catch (e) {
                appDebugLog('[MilkdownRuntimeTag] eval_failed: $e');
              }
              await controller.evaluateJavascript(
                source:
                    '''
                  (function() {
                    if (window.__USHIO_BRIDGE__ && window.__USHIO_BRIDGE__.emitDebug) {
                      window.__USHIO_BRIDGE__.emitDebug('[Flutter] onLoadStop - baseDirectory: "${widget.baseDirectory ?? ''}"');
                    }
                  })();
                ''',
              );
            }
            appDebugLog('[WEBVIEW] onLoadStop: calling _sendInitDoc()');
            await _sendInitDoc();
            openTrace('document handed to webview');
            appDebugLog('[WEBVIEW] onLoadStop: calling _sendTheme()');
            await _sendTheme();
            await _resendKeyboardMetrics();
            appDebugLog('[WEBVIEW] onLoadStop: done');
          },
          onLoadResourceWithCustomScheme: (controller, request) async {
            // 这里每请求一次就会读一张本地图片；曾经为打日志额外做一次 Dart→JS
            // 往返，等于给每张图都加一次平台通道延迟，故不再记录。
            return _serveLocalFileRequest(Uri.parse(request.url.toString()));
          },
          onConsoleMessage: (controller, consoleMessage) {
            appDebugLog('[WebView Console] ${consoleMessage.message}');
          },
        ),
        // 加载遮罩：内容就绪后淡出而不是直接摘掉，避免「骨架屏 → 内容」的硬切
        // 被感知成一次卡顿。淡出结束后才真正移出树，避免留一层空转的透明层。
        if (_overlayMounted)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _didFinishFirstRender ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              onEnd: () {
                if (_didFinishFirstRender && _overlayMounted && mounted) {
                  setState(() => _overlayMounted = false);
                }
              },
              child: IgnorePointer(
                ignoring: _didFinishFirstRender,
                child: _renderTimedOut
                    ? _buildRenderTimeoutOverlay()
                    : _buildLoadingSkeleton(
                        context,
                        _renderProgress > 0
                            ? '正在加载内容... ${(_renderProgress * 100).round()}%'
                            : '正在加载内容...',
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRenderTimeoutOverlay() {
    return Container(
      color: Theme.of(context).extension<AppStyleTheme>()!.useLiquidGlass
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_top,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('仍在加载，可继续等待或返回'),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() => _renderTimedOut = false);
                  _startFirstRenderTimer();
                },
                child: const Text('继续等待'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: widget.onRenderTimeoutExit,
                child: const Text('返回'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      // 加载期间必须是实色底板。之前跟随液态玻璃取透明，结果路由淡入时整页是
      // 「幽灵页」——能透过编辑器看到上一页，内容再在几百毫秒后凭空出现，
      // 这段空窗就是「打开卡顿」的主要观感来源。
      color: colorScheme.surface,
      child: Column(
        children: [
          // Simulated title
          Container(
            height: 32,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // Simulated paragraphs
          ...List.generate(
            5,
            (i) => Container(
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Spacer(),
          // Loading message
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _toCssHex(Color color) {
  final r = (color.r * 255.0).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255.0).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255.0).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}

String _toCssRgba(Color color) {
  final r = (color.r * 255.0).round();
  final g = (color.g * 255.0).round();
  final b = (color.b * 255.0).round();
  final a = color.a;
  return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
}
