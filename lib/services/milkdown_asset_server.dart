import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mime/mime.dart';

import '../utils/constants.dart';

/// 为编辑器 WebView 提供 `assets/milkdown_web/` 下的静态资源。
///
/// 取代 flutter_inappwebview 自带的 `InAppLocalhostServer`，因为后者：
/// - 每个请求都重新 `rootBundle.load` 并整份拷贝字节（2.4MB 的 JS 要走两三次拷贝）；
/// - 响应只有 Content-Type，没有任何缓存头，WebView 因此无法复用 HTTP 缓存和
///   V8 代码缓存，每打开一个文档都要重新解析、重新编译整个 bundle。
///
/// 这里按路径缓存字节，并把资源标记为 immutable：资源名带内容哈希，
/// index.html 的 URL 带应用版本，所以同一版本内可以安全地永久缓存。
class MilkdownAssetServer {
  MilkdownAssetServer({required this.port, required this.documentRoot});

  static MilkdownAssetServer? _sharedServer;
  static Future<MilkdownAssetServer>? _sharedStart;
  static final String _debugStamp = DateTime.now().microsecondsSinceEpoch
      .toString();
  static const String _stampOverride = String.fromEnvironment(
    'MILKDOWN_URL_STAMP',
  );

  /// Editor warmup and formula export share one local asset server.
  static Future<MilkdownAssetServer> ensureSharedStarted() {
    final running = _sharedServer;
    if (running != null && running.isRunning) return Future.value(running);
    return _sharedStart ??= _startShared();
  }

  static Future<MilkdownAssetServer> _startShared() async {
    try {
      for (var offset = 0; offset < 8; offset++) {
        final server = MilkdownAssetServer(
          port: 8080 + offset,
          documentRoot: 'assets/milkdown_web',
        );
        try {
          await server.start();
          _sharedServer = server;
          return server;
        } on SocketException {
          // An unrelated process can occupy the preferred localhost port.
        }
      }
      throw const SocketException('No Milkdown asset server port available');
    } finally {
      _sharedStart = null;
    }
  }

  Uri entryUri([String entry = 'index.html']) {
    if (!RegExp(r'^[\w.-]+\.html$').hasMatch(entry) || entry.contains('..')) {
      throw ArgumentError.value(
        entry,
        'entry',
        'Expected a flat HTML filename',
      );
    }
    final stamp = kDebugMode
        ? _debugStamp
        : (_stampOverride.isEmpty
              ? AppConstants.appVersion
              : '${AppConstants.appVersion}-$_stampOverride');
    return Uri(
      scheme: 'http',
      host: 'localhost',
      port: port,
      path: '/$entry',
      queryParameters: {'v': stamp},
    );
  }

  final int port;
  final String documentRoot;

  HttpServer? _server;
  final Map<String, Uint8List> _assetCache = <String, Uint8List>{};

  bool get isRunning => _server != null;

  String get _root =>
      documentRoot.endsWith('/') ? documentRoot : '$documentRoot/';

  /// 预读入口资源：index.html 以及它引用的 JS/CSS。
  ///
  /// 把首个文档打开时的 rootBundle 读取（~2.4MB，跨平台通道并整份拷贝）提前到应用
  /// 启动的空闲阶段，首个文档就能直接从内存取字节。
  Future<void> preloadEntryAssets() async {
    final index = await _load('${_root}index.html');
    if (index == null) return;
    final html = utf8.decode(index, allowMalformed: true);
    final refs = RegExp(
      r'\./([\w.~-]+\.(?:js|css))',
    ).allMatches(html).map((m) => m.group(1)!).toSet();
    for (final ref in refs) {
      await _load('$_root$ref');
    }
  }

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen(
      (request) => _handle(request, _root),
      onError: (Object error, StackTrace stack) {
        debugPrint('[MilkdownAssetServer] stream error: $error');
      },
      cancelOnError: false,
    );
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: true);
    _assetCache.clear();
  }

  Future<void> _handle(HttpRequest request, String root) async {
    final path = _resolvePath(request.uri.path, root);
    final response = request.response;
    try {
      if (path == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final bytes = await _load(path);
      if (bytes == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      response.headers.contentType = _contentType(path);
      // 资源名带内容哈希，index.html 的 URL 又按应用版本加了查询参数，
      // 同一版本内不可能变化，因此可以声明永久缓存、跳过协商。
      response.headers.set(
        HttpHeaders.cacheControlHeader,
        'public, max-age=31536000, immutable',
      );
      response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
      response.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
    } catch (error) {
      debugPrint('[MilkdownAssetServer] request failed: $error');
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {
        // 连接已被客户端断开，忽略
      }
    }
  }

  /// 只映射 documentRoot 下的纯文件名，杜绝 `..` 之类的路径穿越。
  String? _resolvePath(String uriPath, String root) {
    var name = uriPath.startsWith('/') ? uriPath.substring(1) : uriPath;
    if (name.isEmpty || name == '/') name = 'index.html';
    name = Uri.decodeFull(name);
    if (name.contains('/') || name.contains(r'\') || name.contains('..')) {
      return null;
    }
    return '$root$name';
  }

  Future<Uint8List?> _load(String assetKey) async {
    final cached = _assetCache[assetKey];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(assetKey);
      final bytes = data.buffer.asUint8List();
      _assetCache[assetKey] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  // index.html 的 URL 已按应用版本加查询参数，跨版本不会命中旧缓存。
  ContentType _contentType(String name) {
    final mime = lookupMimeType(name);
    if (mime == null) return ContentType('application', 'octet-stream');
    final parts = mime.split('/');
    final isText =
        mime.endsWith('javascript') ||
        mime.endsWith('css') ||
        mime.endsWith('html') ||
        mime.endsWith('json') ||
        mime.endsWith('svg') ||
        mime.endsWith('xml');
    return ContentType(
      parts.length > 1 ? parts[0] : 'application',
      parts.length > 1 ? parts[1] : 'octet-stream',
      charset: isText ? 'utf-8' : null,
    );
  }
}
