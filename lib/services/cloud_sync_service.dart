// ============================================================================
// 云同步服务
// 
// 协调本地工作区与 WebDAV 远程服务器的同步：
// - 全量同步
// - 单文件同步
// - 冲突解决（最新保存优先）
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'webdav_service.dart';
import 'my_files_service.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// 同步状态枚举
enum SyncStatus {
  idle,       // 空闲
  syncing,    // 同步中
  success,    // 成功
  error,      // 错误
}

/// 同步结果
class SyncResult {
  final bool success;
  final int uploadedCount;
  final int downloadedCount;
  final int deletedCount;
  final String? errorMessage;
  
  const SyncResult({
    required this.success,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.deletedCount = 0,
    this.errorMessage,
  });
  
  factory SyncResult.failed(String message) {
    return SyncResult(success: false, errorMessage: message);
  }
  
  factory SyncResult.empty() {
    return const SyncResult(success: true);
  }
}

/// 同步冲突类型
enum ConflictResolution {
  keepLocal,    // 保留本地版本
  keepRemote,   // 保留远程版本
  skip,         // 跳过此文件
}

/// 同步冲突信息
class SyncConflict {
  final String relativePath;
  final String localPath;
  final DateTime localModified;
  final DateTime remoteModified;
  ConflictResolution resolution;
  
  SyncConflict({
    required this.relativePath,
    required this.localPath,
    required this.localModified,
    required this.remoteModified,
    this.resolution = ConflictResolution.skip,
  });
  
  /// 本地是否更新
  bool get isLocalNewer => localModified.isAfter(remoteModified);
  
  /// 时间差（绝对值，秒）
  int get timeDifferenceSeconds => 
      (localModified.difference(remoteModified).inSeconds).abs();
}

/// 预览结果（同步前的检测结果）
class SyncPreview {
  final List<String> toUpload;      // 需要上传的文件（本地新增）
  final List<String> toDownload;    // 需要下载的文件（远程新增）
  final List<SyncConflict> conflicts; // 存在冲突的文件
  
  const SyncPreview({
    this.toUpload = const [],
    this.toDownload = const [],
    this.conflicts = const [],
  });
  
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get isEmpty => toUpload.isEmpty && toDownload.isEmpty && conflicts.isEmpty;
}

/// 云同步服务类
class CloudSyncService {
  final WebDAVService _webdavService;
  final MyFilesService _myFilesService;
  
  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;
  
  /// 同步状态变化回调
  ValueNotifier<SyncStatus> statusNotifier = ValueNotifier(SyncStatus.idle);
  
  CloudSyncService({
    required WebDAVService webdavService,
    required MyFilesService myFilesService,
  })  : _webdavService = webdavService,
        _myFilesService = myFilesService;
  
  /// 执行全量同步
  /// 
  /// [resolvedConflicts] 用户已解决的冲突列表（可选）
  /// 如果没有提供，发现冲突时将跳过冲突文件
  Future<SyncResult> syncAll({List<SyncConflict>? resolvedConflicts}) async {
    if (_status == SyncStatus.syncing) {
      return SyncResult.failed('同步进行中，请稍候');
    }
    
    _setStatus(SyncStatus.syncing);
    
    try {
      // 测试连接
      if (!await _webdavService.testConnection()) {
        _setStatus(SyncStatus.error);
        return SyncResult.failed('无法连接到 WebDAV 服务器');
      }
      
      // 确保远程工作区存在
      await _webdavService.ensureRemoteWorkspace();
      
      int uploaded = 0;
      int downloaded = 0;
      int skipped = 0;
      
      // 获取本地文件列表
      final localFiles = await _collectLocalFiles();
      
      // 获取远程文件列表
      final remoteFiles = await _collectRemoteFiles();
      
      // 构建已解决冲突的路径映射
      final resolvedMap = <String, ConflictResolution>{};
      if (resolvedConflicts != null) {
        for (final conflict in resolvedConflicts) {
          resolvedMap[conflict.relativePath] = conflict.resolution;
        }
      }
      
      // 同步本地到远程（上传新文件或更新的文件）
      for (final localFile in localFiles) {
        final relativePath = await _getRelativePath(localFile.path);
        final remoteFile = _findRemoteFile(remoteFiles, relativePath);
        
        if (remoteFile == null) {
          // 远程不存在，上传
          if (await _webdavService.uploadFile(localFile.path, relativePath)) {
            uploaded++;
          }
        } else {
          // 比较修改时间
          final localMtime = await localFile.lastModified();
          final remoteMtime = remoteFile.mTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          
          // 检查是否有用户决定的冲突解决方案
          final resolution = resolvedMap[relativePath];
          if (resolution != null) {
            switch (resolution) {
              case ConflictResolution.keepLocal:
                if (await _webdavService.uploadFile(localFile.path, relativePath)) {
                  uploaded++;
                }
                break;
              case ConflictResolution.keepRemote:
                if (await _webdavService.downloadFile(relativePath, localFile.path)) {
                  downloaded++;
                }
                break;
              case ConflictResolution.skip:
                skipped++;
                break;
            }
          } else {
            // 无用户决定，按时间戳自动处理（仅当时间差超过5秒才视为不同）
            final timeDiff = localMtime.difference(remoteMtime).inSeconds.abs();
            if (timeDiff <= 5) {
              // 时间差很小，视为相同，跳过
              continue;
            }
            
            if (localMtime.isAfter(remoteMtime)) {
              // 本地更新，上传
              if (await _webdavService.uploadFile(localFile.path, relativePath)) {
                uploaded++;
              }
            } else if (remoteMtime.isAfter(localMtime)) {
              // 远程更新，下载
              if (await _webdavService.downloadFile(relativePath, localFile.path)) {
                downloaded++;
              }
            }
          }
        }
      }
      
      // 同步远程到本地（下载新文件）
      final workspacePath = await _myFilesService.getWorkspacePath();
      for (final remoteFile in remoteFiles) {
        if (remoteFile.isDir ?? false) continue;
        
        final relativePath = _getRemoteRelativePath(remoteFile.path ?? '');
        final localPath = '$workspacePath${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
        
        if (!await File(localPath).exists()) {
          // 本地不存在，下载
          if (await _webdavService.downloadFile(relativePath, localPath)) {
            downloaded++;
          }
        }
      }
      
      _setStatus(SyncStatus.success);
      return SyncResult(
        success: true,
        uploadedCount: uploaded,
        downloadedCount: downloaded,
        deletedCount: skipped,
      );
    } catch (e) {
      debugPrint('CloudSync 同步失败: $e');
      _setStatus(SyncStatus.error);
      return SyncResult.failed('同步失败: $e');
    }
  }
  
  /// 预览同步（检测冲突）
  /// 
  /// 返回需要上传、下载的文件列表，以及存在冲突的文件列表
  /// 用于在同步前显示确认对话框
  Future<SyncPreview?> previewSync() async {
    try {
      // 测试连接
      if (!await _webdavService.testConnection()) {
        return null;
      }
      
      final toUpload = <String>[];
      final toDownload = <String>[];
      final conflicts = <SyncConflict>[];
      
      // 获取本地文件列表
      final localFiles = await _collectLocalFiles();
      
      // 获取远程文件列表
      final remoteFiles = await _collectRemoteFiles();
      
      // 检查本地文件
      for (final localFile in localFiles) {
        final relativePath = await _getRelativePath(localFile.path);
        final remoteFile = _findRemoteFile(remoteFiles, relativePath);
        
        if (remoteFile == null) {
          // 远程不存在，需要上传
          toUpload.add(relativePath);
        } else {
          // 比较修改时间
          final localMtime = await localFile.lastModified();
          final remoteMtime = remoteFile.mTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          
          // 时间差超过5秒视为冲突
          final timeDiff = localMtime.difference(remoteMtime).inSeconds.abs();
          if (timeDiff > 5) {
            conflicts.add(SyncConflict(
              relativePath: relativePath,
              localPath: localFile.path,
              localModified: localMtime,
              remoteModified: remoteMtime,
            ));
          }
        }
      }
      
      // 检查远程文件
      final workspacePath = await _myFilesService.getWorkspacePath();
      for (final remoteFile in remoteFiles) {
        if (remoteFile.isDir ?? false) continue;
        
        final relativePath = _getRemoteRelativePath(remoteFile.path ?? '');
        final localPath = '$workspacePath${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
        
        if (!await File(localPath).exists()) {
          // 本地不存在，需要下载
          toDownload.add(relativePath);
        }
      }
      
      return SyncPreview(
        toUpload: toUpload,
        toDownload: toDownload,
        conflicts: conflicts,
      );
    } catch (e) {
      debugPrint('CloudSync 预览失败: $e');
      return null;
    }
  }

  
  /// 同步单个文件
  /// 
  /// [localPath] 本地文件路径
  Future<bool> syncFile(String localPath) async {
    try {
      final relativePath = await _getRelativePath(localPath);
      return await _webdavService.uploadFile(localPath, relativePath);
    } catch (e) {
      debugPrint('CloudSync 单文件同步失败: $e');
      return false;
    }
  }
  
  // ==================== 私有方法 ====================
  
  void _setStatus(SyncStatus status) {
    _status = status;
    statusNotifier.value = status;
  }
  
  /// 收集本地所有文件
  Future<List<File>> _collectLocalFiles() async {
    final workspacePath = await _myFilesService.getWorkspacePath();
    final files = <File>[];
    
    await _collectFilesRecursive(Directory(workspacePath), files);
    return files;
  }
  
  Future<void> _collectFilesRecursive(Directory dir, List<File> files) async {
    if (!await dir.exists()) return;
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add(entity);
      } else if (entity is Directory) {
        await _collectFilesRecursive(entity, files);
      }
    }
  }
  
  /// 收集远程所有文件（递归）
  Future<List<webdav.File>> _collectRemoteFiles() async {
    final files = <webdav.File>[];
    await _collectRemoteFilesRecursive('', files);
    return files;
  }
  
  Future<void> _collectRemoteFilesRecursive(String path, List<webdav.File> files) async {
    final remoteFiles = await _webdavService.listRemoteFiles(remotePath: path);
    if (remoteFiles == null) return;
    
    for (final file in remoteFiles) {
      if (file.isDir ?? false) {
        final subPath = path.isEmpty ? file.name! : '$path/${file.name}';
        await _collectRemoteFilesRecursive(subPath, files);
      } else {
        files.add(file);
      }
    }
  }
  
  /// 获取相对于工作区的路径
  Future<String> _getRelativePath(String absolutePath) async {
    final workspacePath = await _myFilesService.getWorkspacePath();
    if (absolutePath.startsWith(workspacePath)) {
      return absolutePath
          .substring(workspacePath.length + 1)
          .replaceAll(Platform.pathSeparator, '/');
    }
    return absolutePath.split(Platform.pathSeparator).last;
  }
  
  /// 获取远程文件相对路径
  String _getRemoteRelativePath(String remotePath) {
    const prefix = '/${WebDAVService.remoteWorkspaceName}/';
    if (remotePath.startsWith(prefix)) {
      return remotePath.substring(prefix.length);
    }
    return remotePath;
  }
  
  /// 在远程文件列表中查找文件
  webdav.File? _findRemoteFile(List<webdav.File> remoteFiles, String relativePath) {
    for (final file in remoteFiles) {
      final remoteRelative = _getRemoteRelativePath(file.path ?? '');
      if (remoteRelative == relativePath) {
        return file;
      }
    }
    return null;
  }
}
