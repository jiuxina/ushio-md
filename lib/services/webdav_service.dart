// ============================================================================
// WebDAV 服务
//
// 封装 WebDAV 客户端操作，提供：
// - 连接测试
// - 文件上传/下载
// - 目录列表
// - 文件删除
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'sync_service_interface.dart';
import '../utils/debug_log.dart';

/// WebDAV 连接配置
class WebDAVConfig {
  final String url;
  final String username;
  final String password;

  const WebDAVConfig({
    required this.url,
    required this.username,
    required this.password,
  });

  /// 检查配置是否完整
  bool get isValid =>
      url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// 从 Map 创建配置
  factory WebDAVConfig.fromMap(Map<String, dynamic> map) {
    return WebDAVConfig(
      url: map['url'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {'url': url, 'username': username, 'password': password};
  }
}

/// WebDAV 服务类
class WebDAVService implements SyncServiceInterface {
  webdav.Client? _client;

  /// 云端工作区目录名称（可配置）
  String _remoteWorkspaceName = 'Ushio-MD';

  /// 云端路径前缀（可配置）
  String _remotePathPrefix = '';

  /// 获取当前工作区名称
  @override
  String get remoteWorkspaceName => _remoteWorkspaceName;

  /// 获取当前路径前缀
  @override
  String get remotePathPrefix => _remotePathPrefix;

  /// 设置工作区名称
  @override
  void setRemoteWorkspaceName(String name) {
    _remoteWorkspaceName = name;
  }

  /// 设置远程路径前缀
  @override
  void setRemotePathPrefix(String prefix) {
    _remotePathPrefix = prefix;
  }

  /// 获取完整的远程工作区路径（路径前缀 + 文件夹名称）
  @override
  String getFullRemotePath() {
    String fullPath = _remotePathPrefix.trim();

    // 确保路径以 / 开头
    if (fullPath.isNotEmpty && !fullPath.startsWith('/')) {
      fullPath = '/$fullPath';
    }

    // 确保路径以 / 结尾（如果有路径前缀）
    if (fullPath.isNotEmpty && !fullPath.endsWith('/')) {
      fullPath += '/';
    }

    // 自动补齐文件夹名称（如果路径不以文件夹名称结尾）
    if (!fullPath.endsWith('$_remoteWorkspaceName/') &&
        !fullPath.endsWith(_remoteWorkspaceName)) {
      fullPath += _remoteWorkspaceName;
    }

    // 如果没有路径前缀，直接返回 /文件夹名称
    if (_remotePathPrefix.trim().isEmpty) {
      return '/$_remoteWorkspaceName';
    }

    return fullPath;
  }

  /// 初始化 WebDAV 客户端
  void initialize(WebDAVConfig config) {
    if (!config.isValid) {
      _client = null;
      return;
    }

    _client = webdav.newClient(
      config.url,
      user: config.username,
      password: config.password,
      debug: false,
    );

    // 设置公共请求头
    _client!.setHeaders({'accept-charset': 'utf-8'});
  }

  /// 测试连接
  @override
  Future<bool> testConnection() async {
    if (_client == null) return false;

    try {
      await _client!.ping();
      return true;
    } catch (e) {
      appDebugLog('WebDAV 连接测试失败: $e');
      return false;
    }
  }

  /// 确保远程工作区目录存在
  @override
  Future<void> ensureRemoteWorkspace() async {
    if (_client == null) return;

    try {
      final remotePath = getFullRemotePath();
      await _client!.mkdir(remotePath);
    } catch (e) {
      // 目录可能已存在，忽略错误，但记录详细日志便于调试
      appDebugLog('WebDAV 创建远程工作区目录失败 (可能已存在): ${getFullRemotePath()} - $e');
    }
  }

  /// 列出远程目录内容
  ///
  /// [remotePath] 远程路径（相对于工作区根目录）
  @override
  Future<List<RemoteFileInfo>?> listRemoteFiles({
    String remotePath = '',
  }) async {
    if (_client == null) return null;

    try {
      final fullRemotePath = getFullRemotePath();
      final path = remotePath.isEmpty
          ? fullRemotePath
          : '$fullRemotePath/$remotePath';

      final files = await _client!.readDir(path);

      // 转换为通用格式
      return files
          .map(
            (f) => RemoteFileInfo(
              name: f.name ?? '',
              path: f.path ?? '',
              isDirectory: f.isDir ?? false,
              modifiedTime: f.mTime,
            ),
          )
          .toList();
    } catch (e) {
      appDebugLog('WebDAV 列出目录失败: $e');
      return null;
    }
  }

  /// 上传文件
  ///
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径（相对于工作区）
  @override
  Future<bool> uploadFile(String localPath, String remotePath) async {
    if (_client == null) return false;

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        appDebugLog('WebDAV 上传失败：本地文件不存在 $localPath');
        return false;
      }

      final fullRemotePath = getFullRemotePath();
      final targetPath = '$fullRemotePath/$remotePath';

      // 确保父目录存在
      final parentPath = targetPath.substring(0, targetPath.lastIndexOf('/'));
      await _ensureRemoteDir(parentPath);

      // 上传文件
      await _client!.writeFromFile(localPath, targetPath);
      appDebugLog('WebDAV 上传成功: $localPath -> $targetPath');
      return true;
    } catch (e) {
      appDebugLog('WebDAV 上传失败: $e');
      return false;
    }
  }

  /// 下载文件
  ///
  /// [remotePath] 远程文件路径（相对于工作区）
  /// [localPath] 本地保存路径
  @override
  Future<bool> downloadFile(String remotePath, String localPath) async {
    if (_client == null) return false;

    try {
      final fullRemotePath = getFullRemotePath();
      final sourcePath = '$fullRemotePath/$remotePath';

      // 确保本地父目录存在
      final localDir = localPath.substring(
        0,
        localPath.lastIndexOf(Platform.pathSeparator),
      );
      await Directory(localDir).create(recursive: true);

      // 下载文件
      await _client!.read2File(sourcePath, localPath);
      appDebugLog('WebDAV 下载成功: $sourcePath -> $localPath');
      return true;
    } catch (e) {
      appDebugLog('WebDAV 下载失败: $e');
      return false;
    }
  }

  /// 删除远程文件或目录
  @override
  Future<bool> deleteRemote(String remotePath) async {
    if (_client == null) return false;

    try {
      final fullRemotePath = getFullRemotePath();
      final targetPath = '$fullRemotePath/$remotePath';
      await _client!.remove(targetPath);
      appDebugLog('WebDAV 删除成功: $targetPath');
      return true;
    } catch (e) {
      appDebugLog('WebDAV 删除失败: $e');
      return false;
    }
  }

  /// 获取远程文件信息
  @override
  Future<RemoteFileInfo?> getRemoteFileInfo(String remotePath) async {
    if (_client == null) return null;

    try {
      final parentPath = remotePath.contains('/')
          ? remotePath.substring(0, remotePath.lastIndexOf('/'))
          : '';
      final fileName = remotePath.contains('/')
          ? remotePath.substring(remotePath.lastIndexOf('/') + 1)
          : remotePath;

      final files = await listRemoteFiles(remotePath: parentPath);
      return files?.firstWhere(
        (f) => f.name == fileName,
        orElse: () => throw Exception('文件不存在'),
      );
    } catch (e) {
      appDebugLog('WebDAV 获取远程文件信息失败: $remotePath - $e');
      return null;
    }
  }

  // ==================== 私有方法 ====================

  /// 确保远程目录存在（递归创建）
  Future<void> _ensureRemoteDir(String remotePath) async {
    if (_client == null) return;

    final parts = remotePath.split('/').where((p) => p.isNotEmpty).toList();
    String currentPath = '';

    for (final part in parts) {
      currentPath += '/$part';
      try {
        await _client!.mkdir(currentPath);
      } catch (e) {
        // 目录可能已存在，忽略错误，但记录详细日志便于调试
        appDebugLog('WebDAV 创建目录失败 (可能已存在): $currentPath - $e');
      }
    }
  }
}
