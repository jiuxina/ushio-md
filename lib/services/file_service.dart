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
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/markdown_file.dart';

/// 文件服务类
/// 
/// 提供文件系统的底层操作封装
class FileService {
  static const int _maxCachedFiles = 24;
  static final LinkedHashMap<String, _CachedFileContent> _contentCache =
      LinkedHashMap<String, _CachedFileContent>();

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
  Future<String?> pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
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
            files.add(MarkdownFile(
              path: entity.path,
              name: entity.path.split(Platform.pathSeparator).last,
              lastModified: stat.modified,
              size: stat.size,
            ));
          }
        }
      }
    } catch (e) {
      // 优雅处理权限错误等情况
      debugPrint('Error listing files: $e');
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
      debugPrint('Error listing directories: $e');
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
  /// 抛出异常如果文件不存在
  Future<String> readFile(String path, {bool allowCache = true}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    final stat = await file.stat();
    if (allowCache) {
      final cached = _contentCache[path];
      if (cached != null &&
          cached.lastModified == stat.modified &&
          cached.size == stat.size) {
        _touchCacheEntry(path, cached);
        return cached.content;
      }
    }

    final content = await file.readAsString();
    _storeInCache(
      path,
      content,
      lastModified: stat.modified,
      size: stat.size,
    );
    return content;
  }

  /// 预加载文件内容到内存缓存，供进入编辑器前使用。
  Future<String> preloadFile(String path) async {
    return readFile(path, allowCache: true);
  }

  /// 同步检查文件是否已有可直接使用的内存缓存。
  bool isFileCached(String path) {
    final cached = _contentCache[path];
    if (cached == null) return false;

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

  /// 保存文件内容
  /// 
  /// [path] 文件的绝对路径
  /// [content] 要写入的内容
  Future<void> saveFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
    final stat = await file.stat();
    _storeInCache(
      path,
      content,
      lastModified: stat.modified,
      size: stat.size,
    );
  }

  /// 创建新的 Markdown 文件
  /// 
  /// [directoryPath] 目标目录路径
  /// [fileName] 文件名（自动添加 .md 扩展名）
  /// 
  /// 新文件包含默认的标题模板
  /// 抛出异常如果文件已存在
  Future<MarkdownFile> createFile(String directoryPath, String fileName) async {
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
    await file.writeAsString('# $fileName\n\n');

    final stat = await file.stat();
    return MarkdownFile(
      path: path,
      name: fileName,
      content: '# $fileName\n\n',
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
  /// 抛出异常如果目标文件已存在
  Future<String> renameFile(String oldPath, String newName) async {
    if (!newName.endsWith('.md')) {
      newName = '$newName.md';
    }

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
    );

    while (_contentCache.length > _maxCachedFiles) {
      _contentCache.remove(_contentCache.keys.first);
    }
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
      final externalRoot = Platform.environment['EXTERNAL_STORAGE'] ?? '/storage/emulated/0';
      
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

  const _CachedFileContent({
    required this.content,
    required this.lastModified,
    required this.size,
  });
}
