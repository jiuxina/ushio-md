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
  bool get isValid => url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
  
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
    return {
      'url': url,
      'username': username,
      'password': password,
    };
  }
}

/// WebDAV 服务类
class WebDAVService {
  webdav.Client? _client;
  
  /// 云端工作区目录名称
  static const String remoteWorkspaceName = 'Ushio-MD';
  
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
  Future<bool> testConnection() async {
    if (_client == null) return false;
    
    try {
      await _client!.ping();
      return true;
    } catch (e) {
      debugPrint('WebDAV 连接测试失败: $e');
      return false;
    }
  }
  
  /// 确保远程工作区目录存在
  Future<void> ensureRemoteWorkspace() async {
    if (_client == null) return;
    
    try {
      await _client!.mkdir('/$remoteWorkspaceName');
    } catch (e) {
      // 目录可能已存在，忽略错误
      debugPrint('WebDAV 创建远程目录: $e');
    }
  }
  
  /// 列出远程目录内容
  /// 
  /// [remotePath] 远程路径（相对于工作区根目录）
  Future<List<webdav.File>?> listRemoteFiles({String remotePath = ''}) async {
    if (_client == null) return null;
    
    try {
      final path = remotePath.isEmpty 
          ? '/$remoteWorkspaceName' 
          : '/$remoteWorkspaceName/$remotePath';
      
      return await _client!.readDir(path);
    } catch (e) {
      debugPrint('WebDAV 列出目录失败: $e');
      return null;
    }
  }
  
  /// 上传文件
  /// 
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径（相对于工作区）
  Future<bool> uploadFile(String localPath, String remotePath) async {
    if (_client == null) return false;
    
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('WebDAV 上传失败：本地文件不存在 $localPath');
        return false;
      }
      
      final fullRemotePath = '/$remoteWorkspaceName/$remotePath';
      
      // 确保父目录存在
      final parentPath = fullRemotePath.substring(0, fullRemotePath.lastIndexOf('/'));
      await _ensureRemoteDir(parentPath);
      
      // 上传文件
      await _client!.writeFromFile(localPath, fullRemotePath);
      debugPrint('WebDAV 上传成功: $localPath -> $fullRemotePath');
      return true;
    } catch (e) {
      debugPrint('WebDAV 上传失败: $e');
      return false;
    }
  }
  
  /// 下载文件
  /// 
  /// [remotePath] 远程文件路径（相对于工作区）
  /// [localPath] 本地保存路径
  Future<bool> downloadFile(String remotePath, String localPath) async {
    if (_client == null) return false;
    
    try {
      final fullRemotePath = '/$remoteWorkspaceName/$remotePath';
      
      // 确保本地父目录存在
      final localDir = localPath.substring(0, localPath.lastIndexOf(Platform.pathSeparator));
      await Directory(localDir).create(recursive: true);
      
      // 下载文件
      await _client!.read2File(fullRemotePath, localPath);
      debugPrint('WebDAV 下载成功: $fullRemotePath -> $localPath');
      return true;
    } catch (e) {
      debugPrint('WebDAV 下载失败: $e');
      return false;
    }
  }
  
  /// 删除远程文件或目录
  Future<bool> deleteRemote(String remotePath) async {
    if (_client == null) return false;
    
    try {
      final fullRemotePath = '/$remoteWorkspaceName/$remotePath';
      await _client!.remove(fullRemotePath);
      debugPrint('WebDAV 删除成功: $fullRemotePath');
      return true;
    } catch (e) {
      debugPrint('WebDAV 删除失败: $e');
      return false;
    }
  }
  
  /// 获取远程文件信息
  Future<webdav.File?> getRemoteFileInfo(String remotePath) async {
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
        // 目录可能已存在
      }
    }
  }
}
