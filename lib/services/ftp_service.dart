// ============================================================================
// FTP 服务
//
// 封装 FTP 客户端操作，提供：
// - 连接测试
// - 文件上传/下载
// - 目录列表
// - 文件删除
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'sync_service_interface.dart';

/// FTP 连接配置
class FTPConfig {
  final String host;
  final int port;
  final String username;
  final String password;

  const FTPConfig({
    required this.host,
    this.port = 21,
    required this.username,
    required this.password,
  });

  /// 检查配置是否完整
  bool get isValid => host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  /// 从 Map 创建配置
  factory FTPConfig.fromMap(Map<String, dynamic> map) {
    return FTPConfig(
      host: map['host'] ?? '',
      port: map['port'] ?? 21,
      username: map['username'] ?? '',
      password: map['password'] ?? '',
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
}

/// FTP 服务类
class FTPService implements SyncServiceInterface {
  FTPConnect? _ftpClient;
  FTPConfig? _config;

  /// 云端工作区目录名称（可配置）
  @override
  String _remoteWorkspaceName = 'Ushio-MD';

  /// 云端路径前缀（可配置）
  @override
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
    if (!fullPath.endsWith('$_remoteWorkspaceName/') && !fullPath.endsWith(_remoteWorkspaceName)) {
      fullPath += _remoteWorkspaceName;
    }

    // 如果没有路径前缀，直接返回 /文件夹名称
    if (_remotePathPrefix.trim().isEmpty) {
      return '/$_remoteWorkspaceName';
    }

    return fullPath;
  }

  /// 初始化 FTP 客户端
  void initialize(FTPConfig config) {
    if (!config.isValid) {
      _ftpClient = null;
      _config = null;
      return;
    }

    _config = config;
    _ftpClient = FTPConnect(
      config.host,
      port: config.port,
      user: config.username,
      pass: config.password,
    );
  }

  /// 测试连接
  @override
  Future<bool> testConnection() async {
    if (_ftpClient == null) return false;

    try {
      await _ftpClient!.connect();
      await _ftpClient!.disconnect();
      return true;
    } catch (e) {
      debugPrint('FTP 连接测试失败: $e');
      return false;
    }
  }

  /// 确保远程工作区目录存在
  @override
  Future<void> ensureRemoteWorkspace() async {
    if (_ftpClient == null) return;

    try {
      final remotePath = getFullRemotePath();
      await _ftpClient!.connect();

      // 递归创建目录路径
      await _ensureRemoteDir(remotePath);

      await _ftpClient!.disconnect();
    } catch (e) {
      debugPrint('FTP 创建远程目录失败: $e');
      try {
        await _ftpClient!.disconnect();
      } catch (_) {}
    }
  }

  /// 列出远程目录内容
  ///
  /// [remotePath] 远程路径（相对于工作区根目录）
  @override
  Future<List<RemoteFileInfo>?> listRemoteFiles({String remotePath = ''}) async {
    if (_ftpClient == null) return null;

    try {
      await _ftpClient!.connect();

      final fullRemotePath = getFullRemotePath();
      final path = remotePath.isEmpty
          ? fullRemotePath
          : '$fullRemotePath/$remotePath';

      final files = await _ftpClient!.listDirectoryContent(path);

      await _ftpClient!.disconnect();

      // 转换为通用格式
      return files.map((f) => RemoteFileInfo(
        name: f.name,
        path: path + '/' + f.name,
        isDirectory: f.type == FTPEntryType.DIR,
        modifiedTime: f.modifyTime,
      )).toList();
    } catch (e) {
      debugPrint('FTP 列出目录失败: $e');
      try {
        await _ftpClient!.disconnect();
      } catch (_) {}
      return null;
    }
  }

  /// 上传文件
  ///
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径（相对于工作区）
  @override
  Future<bool> uploadFile(String localPath, String remotePath) async {
    if (_ftpClient == null) return false;

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('FTP 上传失败：本地文件不存在 $localPath');
        return false;
      }

      await _ftpClient!.connect();

      final fullRemotePath = getFullRemotePath();
      final targetPath = '$fullRemotePath/$remotePath';

      // 确保父目录存在
      final parentPath = targetPath.substring(0, targetPath.lastIndexOf('/'));
      await _ensureRemoteDir(parentPath);

      // 上传文件
      final success = await _ftpClient!.uploadFile(file, remotePath: targetPath);

      await _ftpClient!.disconnect();

      if (success) {
        debugPrint('FTP 上传成功: $localPath -> $targetPath');
      } else {
        debugPrint('FTP 上传失败: $localPath -> $targetPath');
      }
      return success;
    } catch (e) {
      debugPrint('FTP 上传失败: $e');
      try {
        await _ftpClient!.disconnect();
      } catch (_) {}
      return false;
    }
  }

  /// 下载文件
  ///
  /// [remotePath] 远程文件路径（相对于工作区）
  /// [localPath] 本地保存路径
  @override
  Future<bool> downloadFile(String remotePath, String localPath) async {
    if (_ftpClient == null) return false;

    try {
      await _ftpClient!.connect();

      final fullRemotePath = getFullRemotePath();
      final sourcePath = '$fullRemotePath/$remotePath';

      // 确保本地父目录存在
      final localDir = localPath.substring(0, localPath.lastIndexOf(Platform.pathSeparator));
      await Directory(localDir).create(recursive: true);

      // 下载文件
      final success = await _ftpClient!.downloadFile(sourcePath, File(localPath));

      await _ftpClient!.disconnect();

      if (success) {
        debugPrint('FTP 下载成功: $sourcePath -> $localPath');
      } else {
        debugPrint('FTP 下载失败: $sourcePath -> $localPath');
      }
      return success;
    } catch (e) {
      debugPrint('FTP 下载失败: $e');
      try {
        await _ftpClient!.disconnect();
      } catch (_) {}
      return false;
    }
  }

  /// 删除远程文件或目录
  @override
  Future<bool> deleteRemote(String remotePath) async {
    if (_ftpClient == null) return false;

    try {
      await _ftpClient!.connect();

      final fullRemotePath = getFullRemotePath();
      final targetPath = '$fullRemotePath/$remotePath';

      final success = await _ftpClient!.deleteFile(targetPath);

      await _ftpClient!.disconnect();

      if (success) {
        debugPrint('FTP 删除成功: $targetPath');
      } else {
        debugPrint('FTP 删除失败: $targetPath');
      }
      return success;
    } catch (e) {
      debugPrint('FTP 删除失败: $e');
      try {
        await _ftpClient!.disconnect();
      } catch (_) {}
      return false;
    }
  }

  /// 获取远程文件信息
  @override
  Future<RemoteFileInfo?> getRemoteFileInfo(String remotePath) async {
    if (_ftpClient == null) return null;

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
      debugPrint('FTP 获取文件信息失败: $e');
      return null;
    }
  }

  // ==================== 私有方法 ====================

  /// 确保远程目录存在（递归创建）
  Future<void> _ensureRemoteDir(String remotePath) async {
    if (_ftpClient == null) return;

    final parts = remotePath.split('/').where((p) => p.isNotEmpty).toList();
    String currentPath = '';

    for (final part in parts) {
      currentPath += '/$part';
      try {
        // 尝试创建目录，如果已存在会失败但不影响后续操作
        await _ftpClient!.makeDirectory(currentPath);
      } catch (e) {
        // 目录可能已存在，继续处理下一级
        debugPrint('FTP 创建目录 $currentPath: $e');
      }
    }
  }
}
