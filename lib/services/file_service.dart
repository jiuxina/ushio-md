// ============================================================================
// 文件服务
//
// 封装所有文件系统操作，包括：
// - 权限管理（Android 存储权限）
// - 文件选择器
// - 文件读写
// - 目录遍历
//
// 使用 file_picker 和 permission_handler 插件。
// ============================================================================

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/markdown_file.dart';
import '../utils/debug_log.dart';

/// 文件过大异常
class FileTooLargeException implements Exception {
  final String message;
  final int actualSize;
  final int maxSize;

  const FileTooLargeException(this.message, this.actualSize, this.maxSize);

  @override
  String toString() => message;
}

/// 文件编码异常
class FileEncodingException implements Exception {
  final String message;
  final String path;

  const FileEncodingException(this.message, this.path);

  @override
  String toString() => message;
}

/// 文件服务类
///
/// 提供文件系统的底层操作封装
class FileService {
  static const int _maxCachedFiles = 24;

  /// 最大文件大小限制 (10MB)
  static const int maxFileSize = 10 * 1024 * 1024;

  /// 二进制探测字节数
  static const int binaryProbeBytes = 8 * 1024;

  /// 最大文件名长度
  static const int maxFileNameLength = 255;

  static final LinkedHashMap<String, _CachedFileContent> _contentCache =
      LinkedHashMap<String, _CachedFileContent>();

  /// 判断字节内容是否看起来像文本（无 NUL 且可按 UTF-8 解码）。
  static bool looksLikeTextBytes(List<int> bytes) {
    if (bytes.isEmpty) return true;
    final probe = bytes.length > binaryProbeBytes
        ? bytes.sublist(0, binaryProbeBytes)
        : bytes;
    if (probe.contains(0)) return false;
    try {
      // 探测块可能截断多字节字符，这里只做 NUL 检测；
      // 完整文件的严格 UTF-8 校验由 readFile 负责。
      utf8.decode(probe, allowMalformed: true);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// 统一换行风格并保留指定的行尾（默认 LF）。
  static String normalizeLineEndings(
    String content, {
    String lineEnding = '\n',
  }) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return lineEnding == '\r\n'
        ? normalized.replaceAll('\n', '\r\n')
        : normalized;
  }

  /// 验证并清理文件名
  ///
  /// - 移除 Windows 非法字符: < > : " | ? *
  /// - 移除控制字符
  /// - 处理 Windows 保留名
  /// - 限制长度
  /// - 空文件名返回默认值
  static String sanitizeFileName(
    String name, {
    String defaultName = 'untitled',
  }) {
    var sanitized = name.trim();

    // 移除路径分隔符，只保留最后一段
    sanitized = sanitized.replaceAll('\\', '/').split('/').last.trim();

    // 移除 Windows 非法字符
    sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*]'), '_');

    // 移除控制字符 (0x00-0x1F)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1f]'), '');

    // 处理 Windows 保留名
    const reservedNames = [
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    ];
    final baseName = sanitized.toUpperCase().split('.').first;
    if (reservedNames.contains(baseName)) {
      sanitized = '_$sanitized';
    }

    // 移除首尾空格和点
    sanitized = sanitized.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');

    // 限制长度
    if (sanitized.length > maxFileNameLength) {
      // 保留扩展名
      final lastDot = sanitized.lastIndexOf('.');
      if (lastDot > 0 && lastDot > sanitized.length - 10) {
        final ext = sanitized.substring(lastDot);
        sanitized =
            sanitized.substring(0, maxFileNameLength - ext.length) + ext;
      } else {
        sanitized = sanitized.substring(0, maxFileNameLength);
      }
    }

    // 空文件名使用默认值
    if (sanitized.isEmpty || sanitized == '.md') {
      sanitized = '$defaultName.md';
    }

    return sanitized;
  }

  /// 确保文件名带有受支持的 Markdown 扩展名。
  ///
  /// 未显式指定 `.md`/`.markdown`/`.txt` 时默认补 `.md`，避免文件在
  /// Markdown 文件列表中因缺少扩展名而“消失”。
  static String ensureMarkdownExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.txt')) {
      return fileName;
    }
    return '$fileName.md';
  }

  /// 检查文件是否过大
  static bool isFileTooLarge(int size) => size > maxFileSize;

  /// 格式化文件大小
  static String formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ==================== 权限管理 ====================

  /// 请求存储权限
  ///
  /// Android 权限策略：
  /// 1. 首先检查是否已有 MANAGE_EXTERNAL_STORAGE 权限
  /// 2. 请求基本存储权限
  /// 3. 对于 Android 11+，需要请求 MANAGE_EXTERNAL_STORAGE
  ///
  /// 返回 true 表示获得权限
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // 检查是否已有完全存储访问权限
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // 请求基本存储权限
      var status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      // Android 11+ 需要额外的管理权限
      status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    // iOS 和其他平台默认返回 true
    return true;
  }

  /// 检查是否已有存储权限
  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      return await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  /// 打开系统设置页面
  ///
  /// 用户可以在设置中手动开启权限
  Future<void> openSettings() async {
    await openAppSettings();
  }

  // ==================== 文件选择器 ====================

  /// 选择目录
  ///
  /// 打开系统目录选择器
  /// 返回选中目录的路径，取消则返回 null
  ///
  /// Android 11+ 注意事项：
  /// - 某些受保护目录（如 Downloads）会返回 "/" 而非实际路径
  /// - 这是 Android Scoped Storage 的限制，而非插件 bug
  /// - 需要确保 MANAGE_EXTERNAL_STORAGE 权限已授权
  Future<String?> pickDirectory() async {
    // 在 Android 上先确保有存储权限
    if (Platform.isAndroid) {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        appDebugLog('FileService: 存储权限未授权，无法选择目录');
        return null;
      }
    }

    final result = await FilePicker.platform.getDirectoryPath();

    // 检查是否返回了无效的根路径（Android Scoped Storage 限制）
    if (result == '/') {
      appDebugLog('FileService: 选择的目录返回了根路径 "/"，可能是受保护的系统目录');
      // 返回 null 表示无法访问该目录
      return null;
    }

    return result;
  }

  /// 选择 Markdown 文件
  ///
  /// 支持的扩展名：.md, .markdown, .txt
  /// 返回选中文件的路径，取消则返回 null
  Future<String?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    return result?.files.single.path;
  }

  // ==================== 目录遍历 ====================

  /// 列出目录下的所有 Markdown 文件（包含子目录）
  ///
  /// [directoryPath] 目录的绝对路径
  ///
  /// 递归扫描所有子目录，返回按修改时间倒序排列的文件列表
  Future<List<MarkdownFile>> listMarkdownFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final files = <MarkdownFile>[];
    try {
      // 递归扫描所有子目录
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final path = entity.path.toLowerCase();
          // 只处理 Markdown 文件
          if (path.endsWith('.md') || path.endsWith('.markdown')) {
            final stat = await entity.stat();
            files.add(
              MarkdownFile(
                path: entity.path,
                name: entity.path.split(Platform.pathSeparator).last,
                lastModified: stat.modified,
                size: stat.size,
              ),
            );
          }
        }
      }
    } catch (e) {
      // 优雅处理权限错误等情况
      appDebugLog('Error listing files: $e');
    }

    // 按修改时间倒序排列（最新的在前）
    files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return files;
  }

  /// 列出目录下的所有子目录
  ///
  /// [directoryPath] 目录的绝对路径
  ///
  /// 返回按路径字母顺序排列的目录列表
  Future<List<Directory>> listSubdirectories(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final dirs = <Directory>[];
    try {
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          dirs.add(entity);
        }
      }
    } catch (e) {
      appDebugLog('Error listing directories: $e');
    }

    // 按路径字母顺序排列
    dirs.sort((a, b) => a.path.compareTo(b.path));
    return dirs;
  }

  // ==================== 文件读写 ====================

  /// 读取文件内容
  ///
  /// [path] 文件的绝对路径
  ///
  /// 抛出异常如果文件不存在或文件过大
  Future<String> readFile(String path, {bool allowCache = true}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    final stat = await file.stat();

    // 检查文件大小
    if (isFileTooLarge(stat.size)) {
      throw FileTooLargeException(
        '文件过大 (${formatFileSize(stat.size)})，最大支持 ${formatFileSize(maxFileSize)}',
        stat.size,
        maxFileSize,
      );
    }

    if (allowCache) {
      final cached = _contentCache[path];
      if (cached != null &&
          !cached.isExpired() &&
          cached.lastModified == stat.modified &&
          cached.size == stat.size) {
        _touchCacheEntry(path, cached);
        return cached.content;
      }
    }

    final bytes = await file.readAsBytes();
    if (!looksLikeTextBytes(bytes)) {
      throw FileEncodingException(
        '文件不是有效的 UTF-8 文本，可能包含二进制内容（$path）',
        path,
      );
    }
    String content;
    try {
      content = utf8.decode(bytes);
    } on FormatException {
      throw FileEncodingException(
        '文件不是有效的 UTF-8 文本（$path）',
        path,
      );
    }
    _storeInCache(path, content, lastModified: stat.modified, size: stat.size);
    return content;
  }

  /// 流式读取大文件（用于超大文件的预览或处理）
  ///
  /// [path] 文件路径
  /// [chunkSize] 每次读取的块大小（字节），默认 64KB
  /// [onChunk] 每读取一块后的回调，返回 false 可中断读取
  ///
  /// 返回总读取字节数
  ///
  /// 注意：此方法不使用缓存
  Future<int> readFileStream(
    String path, {
    int chunkSize = 64 * 1024,
    required Future<bool> Function(String chunk, int bytesRead, int totalBytes)
    onChunk,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    final stat = await file.stat();
    final totalBytes = stat.size;
    int bytesRead = 0;

    final stream = file.openRead();
    final decoder = const Utf8Decoder();

    await for (final chunk in stream) {
      final decoded = decoder.convert(chunk);
      bytesRead += chunk.length;

      final shouldContinue = await onChunk(decoded, bytesRead, totalBytes);
      if (!shouldContinue) {
        break;
      }
    }

    return bytesRead;
  }

  /// 读取文件的前 N 个字符（用于预览）
  ///
  /// [path] 文件路径
  /// [maxChars] 最大字符数，默认 10000
  ///
  /// 返回文件内容的前 maxChars 个字符
  Future<String> readFilePreview(String path, {int maxChars = 10000}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    // 使用随机访问读取文件开头
    final randomAccess = await file.open(mode: FileMode.read);
    try {
      // 读取最多 maxChars * 4 字节（UTF-8 最坏情况）
      final bytesToRead = maxChars * 4;
      final buffer = List<int>.filled(bytesToRead, 0);
      final bytesRead = await randomAccess.readInto(buffer);

      // 截取实际读取的字节
      final actualBytes = buffer.sublist(0, bytesRead);

      // 解码为字符串
      final content = String.fromCharCodes(
        utf8.decode(actualBytes, allowMalformed: true).codeUnits,
      );

      // 截取到 maxChars
      if (content.length > maxChars) {
        return content.substring(0, maxChars);
      }
      return content;
    } finally {
      await randomAccess.close();
    }
  }

  /// 预加载文件内容到内存缓存，供进入编辑器前使用。
  Future<String> preloadFile(String path) async {
    return readFile(path, allowCache: true);
  }

  /// 同步检查文件是否已有可直接使用的内存缓存。
  bool isFileCached(String path) {
    final cached = _contentCache[path];
    if (cached == null) return false;
    if (cached.isExpired()) {
      _contentCache.remove(path);
      return false;
    }

    final file = File(path);
    if (!file.existsSync()) {
      _contentCache.remove(path);
      return false;
    }

    try {
      final stat = file.statSync();
      final isFresh =
          cached.lastModified == stat.modified && cached.size == stat.size;
      if (isFresh) {
        _touchCacheEntry(path, cached);
        return true;
      }
    } catch (_) {
      // 如果 statSync 失败，则视为缓存不可用。
    }

    _contentCache.remove(path);
    return false;
  }

  /// 检查磁盘可用空间
  ///
  /// [path] 要检查的路径（用于确定磁盘）
  /// [requiredBytes] 需要的空间大小（字节）
  ///
  /// 返回是否有足够空间
  Future<bool> hasEnoughSpace(String path, int requiredBytes) async {
    try {
      final file = File(path);
      final parent = file.parent;

      // 尝试获取磁盘空间信息
      // 注意：Dart 标准库不直接支持磁盘空间查询
      // 这里使用一种简化的方法：尝试创建临时文件来测试
      final testFile = File(
        '${parent.path}${Platform.pathSeparator}.space_test_${DateTime.now().millisecondsSinceEpoch}',
      );

      try {
        // 创建一个指定大小的临时文件来测试空间
        final testData = List<int>.filled(requiredBytes, 0);
        await testFile.writeAsBytes(testData, flush: true);
        await testFile.delete();
        return true;
      } catch (e) {
        // 写入失败，可能是空间不足
        try {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        } catch (e) {
          appDebugLog('操作失败: $e');
        }
        return false;
      }
    } catch (e) {
      appDebugLog('检查磁盘空间失败: $e');
      // 无法确定时，假设有空间（让实际写入来决定）
      return true;
    }
  }

  /// 保存文件内容
  ///
  /// [path] 文件的绝对路径
  /// [content] 要写入的内容
  ///
  /// 抛出异常如果磁盘空间不足
  Future<void> saveFile(String path, String content) async {
    final file = File(path);

    // 检查内容大小
    final contentSize = content.length; // UTF-16 代码单元数，近似字节数
    if (isFileTooLarge(contentSize)) {
      throw FileTooLargeException(
        '内容过大 (${formatFileSize(contentSize)})，最大支持 ${formatFileSize(maxFileSize)}',
        contentSize,
        maxFileSize,
      );
    }
    // Atomic write: write to temp file first, then rename
    final tempFile = File('$path.tmp');
    try {
      await tempFile.writeAsString(content, flush: true);
      // On Windows, rename fails if target exists; delete first
      if (Platform.isWindows && await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(path);
    } catch (e) {
      // Clean up temp file on failure
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
    final stat = await file.stat();
    _storeInCache(path, content, lastModified: stat.modified, size: stat.size);
  }

  /// 创建新的 Markdown 文件
  ///
  /// [directoryPath] 目标目录路径
  /// [fileName] 文件名（自动添加 .md 扩展名）
  ///
  /// 新文件包含默认的标题模板
  /// 抛出异常如果文件已存在或文件名非法
  Future<MarkdownFile> createFile(String directoryPath, String fileName) async {
    // 验证并清理文件名
    fileName = sanitizeFileName(fileName, defaultName: 'untitled');

    // 确保有 .md 扩展名
    if (!fileName.endsWith('.md')) {
      fileName = '$fileName.md';
    }

    final path = '$directoryPath${Platform.pathSeparator}$fileName';
    final file = File(path);

    // 检查文件是否已存在
    if (await file.exists()) {
      throw Exception('File already exists: $fileName');
    }

    // 创建文件并写入默认内容
    final titleName = fileName.replaceAll('.md', '');
    await file.writeAsString('# $titleName\n\n');

    final stat = await file.stat();
    return MarkdownFile(
      path: path,
      name: fileName,
      content: '# $titleName\n\n',
      lastModified: stat.modified,
      size: stat.size,
    );
  }

  /// 删除文件
  ///
  /// [path] 文件的绝对路径
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _contentCache.remove(path);
  }

  /// 重命名文件
  ///
  /// [oldPath] 原文件路径
  /// [newName] 新文件名（自动添加 .md 扩展名）
  ///
  /// 返回新文件的路径
  /// 抛出异常如果目标文件已存在或文件名非法
  Future<String> renameFile(String oldPath, String newName) async {
    // 验证并清理文件名
    newName = sanitizeFileName(newName, defaultName: 'untitled');

    newName = ensureMarkdownExtension(newName);

    final file = File(oldPath);
    final directory = file.parent.path;
    final newPath = '$directory${Platform.pathSeparator}$newName';

    if (await File(newPath).exists()) {
      throw Exception('File already exists: $newName');
    }

    await file.rename(newPath);
    final cached = _contentCache.remove(oldPath);
    if (cached != null) {
      _storeInCache(
        newPath,
        cached.content,
        lastModified: cached.lastModified,
        size: cached.size,
      );
    }
    return newPath;
  }

  static void _touchCacheEntry(String path, _CachedFileContent cached) {
    _contentCache.remove(path);
    _contentCache[path] = cached;
  }

  static void _storeInCache(
    String path,
    String content, {
    required DateTime lastModified,
    required int size,
  }) {
    _contentCache.remove(path);
    _contentCache[path] = _CachedFileContent(
      content: content,
      lastModified: lastModified,
      size: size,
      cachedAt: DateTime.now(),
    );

    while (_contentCache.length > _maxCachedFiles) {
      _contentCache.remove(_contentCache.keys.first);
    }
  }

  /// 清除所有过期缓存条目
  static void clearExpiredCache() {
    final expiredKeys = <String>[];
    for (final entry in _contentCache.entries) {
      if (entry.value.isExpired()) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _contentCache.remove(key);
    }
  }

  /// 清除所有缓存（用于内存压力时）
  static void clearAllCache() {
    _contentCache.clear();
  }

  // ==================== 常用路径 ====================

  /// 获取常用存储路径
  ///
  /// Android 设备的常用目录：
  /// - Documents
  /// - Download
  /// - Notes
  /// - 根目录
  ///
  /// 使用动态路径解析，兼容不同设备
  Future<List<String>> getCommonPaths() async {
    final paths = <String>[];

    if (Platform.isAndroid) {
      // 动态获取外部存储根目录，避免硬编码
      final externalRoot =
          Platform.environment['EXTERNAL_STORAGE'] ?? '/storage/emulated/0';

      final commonDirs = [
        '$externalRoot/Documents',
        '$externalRoot/Download',
        '$externalRoot/Notes',
        externalRoot,
      ];

      for (final dir in commonDirs) {
        if (await Directory(dir).exists()) {
          paths.add(dir);
        }
      }
    }

    return paths;
  }
}

class _CachedFileContent {
  final String content;
  final DateTime lastModified;
  final int size;
  final DateTime cachedAt;

  const _CachedFileContent({
    required this.content,
    required this.lastModified,
    required this.size,
    required this.cachedAt,
  });

  /// 缓存是否已过期（默认 5 分钟）
  bool isExpired({Duration ttl = const Duration(minutes: 5)}) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}
