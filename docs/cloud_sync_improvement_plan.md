# 云同步稳定性改进方案

## 问题概述

根据 V1.4.3 release notes:
> 云同步功能(WebDAV/FTP)在不同设备与网络环境下稳定性仍需持续验证

## 已知问题点

### 1. 网络错误处理不足

**当前实现**: `lib/services/webdav_service.dart` 和 `lib/services/ftp_service.dart`

**问题**:
- 缺少指数退避重试机制
- 超时配置不够灵活
- 网络状态检测缺失
- 断点续传未实现

### 2. 并发冲突处理

**当前实现**: `lib/services/cloud_sync_service.dart`

**问题**:
- 冲突检测仅基于修改时间
- 缺少文件哈希校验
- 用户界面提示不够明确
- 缺少手动合并工具

### 3. 错误恢复机制

**问题**:
- 失败操作未持久化
- 无法恢复中断的同步
- 缺少同步历史记录
- 错误信息不够详细

---

## 改进方案

### 方案A: 增强网络错误处理 (立即实施)

#### 1. 添加指数退避重试

**文件**: `lib/services/webdav_service.dart`

**添加方法**:

```dart
/// 指数退避重试包装器
Future<T> _withRetry<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
}) async {
  int attempt = 0;
  Duration delay = initialDelay;
  
  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      
      // 检查是否为可重试错误
      if (!_isRetryableError(e)) {
        rethrow;
      }
      
      if (attempt >= maxRetries) {
        rethrow;
      }
      
      debugPrint('[WebDAV] Retry attempt $attempt/$maxRetries after error: $e');
      
      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 2).clamp(0, maxDelay.inMilliseconds),
      );
    }
  }
}

/// 判断错误是否可重试
bool _isRetryableError(dynamic error) {
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is HttpException) {
    final message = error.message.toLowerCase();
    return message.contains('timeout') ||
           message.contains('connection') ||
           message.contains('network');
  }
  if (error is DioException) {
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.connectionError;
  }
  return false;
}
```

**应用示例**:

```dart
Future<bool> testConnection() async {
  return await _withRetry(() async {
    // 原有连接测试逻辑
    final response = await _client.ping();
    return response.statusCode == 200;
  });
}
```

#### 2. 改进超时配置

**添加配置选项**:

```dart
class WebDAVConfig {
  final String server;
  final String username;
  final String password;
  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration writeTimeout;
  final int maxRetries;
  
  const WebDAVConfig({
    required this.server,
    required this.username,
    required this.password,
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 60),
    this.writeTimeout = const Duration(seconds: 120),
    this.maxRetries = 3,
  });
}
```

#### 3. 网络状态检测

**新文件**: `lib/services/network_service.dart`

```dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final _connectivity = Connectivity();
  
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => 
      result != ConnectivityResult.none
    );
  }
  
  Future<bool> isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => 
      result == ConnectivityResult.wifi
    );
  }
  
  Future<bool> isMobile() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => 
      result == ConnectivityResult.mobile
    );
  }
  
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}
```

---

### 方案B: 改进冲突检测 (短期实施)

#### 1. 文件哈希校验

**文件**: `lib/services/cloud_sync_service.dart`

**添加方法**:

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 计算文件SHA256哈希
Future<String> _calculateFileHash(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    return '';
  }
  
  final bytes = await file.readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString();
}

/// 扩展SyncConflict类
class SyncConflict {
  final String relativePath;
  final String localPath;
  final DateTime localModified;
  final DateTime remoteModified;
  final String? localHash;  // 新增
  final String? remoteHash;  // 新增
  ConflictResolution resolution;
  
  SyncConflict({
    required this.relativePath,
    required this.localPath,
    required this.localModified,
    required this.remoteModified,
    this.localHash,
    this.remoteHash,
    this.resolution = ConflictResolution.skip,
  });
  
  /// 内容是否相同(哈希匹配)
  bool get contentIdentical => 
      localHash != null && 
      remoteHash != null && 
      localHash == remoteHash;
  
  /// 时间差(绝对值,秒)
  int get timeDifferenceSeconds => 
      (localModified.difference(remoteModified).inSeconds).abs();
}
```

#### 2. 增强同步预览

```dart
Future<SyncPreview> previewSync({bool calculateHashes = false}) async {
  final toUpload = <String>[];
  final toDownload = <String>[];
  final conflicts = <SyncConflict>[];
  
  // 获取本地文件列表
  final localFiles = await _getLocalFiles();
  
  // 获取远程文件列表
  final remoteFiles = await _syncService.listFiles();
  
  for (final localFile in localFiles) {
    final relativePath = localFile.relativePath;
    final remoteFile = remoteFiles[relativePath];
    
    if (remoteFile == null) {
      // 远程不存在,需要上传
      toUpload.add(relativePath);
    } else {
      // 两边都存在,检查修改时间
      if (localFile.modified.isAfter(remoteFile.modified)) {
        // 本地更新
        if (calculateHashes) {
          final localHash = await _calculateFileHash(localFile.path);
          final remoteHash = await _syncService.getFileHash(relativePath);
          
          if (localHash != remoteHash) {
            toUpload.add(relativePath);
          }
          // 哈希相同则跳过(内容未变)
        } else {
          toUpload.add(relativePath);
        }
      } else if (localFile.modified.isBefore(remoteFile.modified)) {
        // 远程更新
        if (calculateHashes) {
          final localHash = await _calculateFileHash(localFile.path);
          final remoteHash = await _syncService.getFileHash(relativePath);
          
          if (localHash != remoteHash) {
            toDownload.add(relativePath);
          }
        } else {
          toDownload.add(relativePath);
        }
      } else {
        // 修改时间相同
        if (calculateHashes) {
          // 验证内容
          final localHash = await _calculateFileHash(localFile.path);
          final remoteHash = await _syncService.getFileHash(relativePath);
          
          if (localHash != remoteHash) {
            conflicts.add(SyncConflict(
              relativePath: relativePath,
              localPath: localFile.path,
              localModified: localFile.modified,
              remoteModified: remoteFile.modified,
              localHash: localHash,
              remoteHash: remoteHash,
            ));
          }
        }
      }
    }
  }
  
  // 检查远程独有文件
  for (final entry in remoteFiles.entries) {
    if (!localFiles.any((f) => f.relativePath == entry.key)) {
      toDownload.add(entry.key);
    }
  }
  
  return SyncPreview(
    toUpload: toUpload,
    toDownload: toDownload,
    conflicts: conflicts,
  );
}
```

#### 3. 改进冲突提示UI

**文件**: `lib/screens/settings/sync_conflict_dialog.dart` (新建)

```dart
import 'package:flutter/material.dart';

class SyncConflictDialog extends StatelessWidget {
  final List<SyncConflict> conflicts;
  
  const SyncConflictDialog({
    super.key,
    required this.conflicts,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('同步冲突'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: conflicts.length,
          itemBuilder: (context, index) {
            final conflict = conflicts[index];
            return Card(
              child: ListTile(
                title: Text(conflict.relativePath),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本地修改: ${conflict.localModified}'),
                    Text('远程修改: ${conflict.remoteModified}'),
                    if (conflict.contentIdentical)
                      const Text(
                        '⚠️ 内容相同(仅时间戳不同)',
                        style: TextStyle(color: Colors.orange),
                      ),
                  ],
                ),
                trailing: PopupMenuButton<ConflictResolution>(
                  onSelected: (resolution) {
                    conflict.resolution = resolution;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ConflictResolution.keepLocal,
                      child: Text('保留本地'),
                    ),
                    const PopupMenuItem(
                      value: ConflictResolution.keepRemote,
                      child: Text('使用远程'),
                    ),
                    const PopupMenuItem(
                      value: ConflictResolution.skip,
                      child: Text('跳过'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(conflicts),
          child: const Text('应用选择'),
        ),
      ],
    );
  }
}
```

---

### 方案C: 添加同步状态持久化 (长期实施)

#### 1. 同步历史记录

**新文件**: `lib/services/sync_history_service.dart`

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncHistoryEntry {
  final String relativePath;
  final String operation; // 'upload', 'download', 'skip'
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;
  
  SyncHistoryEntry({
    required this.relativePath,
    required this.operation,
    required this.timestamp,
    required this.success,
    this.errorMessage,
  });
  
  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'operation': operation,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };
  
  factory SyncHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SyncHistoryEntry(
        relativePath: json['relativePath'],
        operation: json['operation'],
        timestamp: DateTime.parse(json['timestamp']),
        success: json['success'],
        errorMessage: json['errorMessage'],
      );
}

class SyncHistoryService {
  static const _maxEntries = 1000;
  final SharedPreferences _prefs;
  
  SyncHistoryService(this._prefs);
  
  Future<void> addEntry(SyncHistoryEntry entry) async {
    final history = await getHistory();
    history.insert(0, entry);
    
    // 限制历史记录数量
    if (history.length > _maxEntries) {
      history.removeRange(_maxEntries, history.length);
    }
    
    await _saveHistory(history);
  }
  
  Future<List<SyncHistoryEntry>> getHistory() async {
    final jsonStrings = _prefs.getStringList('sync_history') ?? [];
    return jsonStrings
        .map((json) => SyncHistoryEntry.fromJson(jsonDecode(json)))
        .toList();
  }
  
  Future<void> _saveHistory(List<SyncHistoryEntry> history) async {
    final jsonStrings = history
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();
    await _prefs.setStringList('sync_history', jsonStrings);
  }
  
  Future<void> clearHistory() async {
    await _prefs.remove('sync_history');
  }
}
```

#### 2. 失败操作队列

**新文件**: `lib/services/sync_retry_queue.dart`

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FailedSyncOperation {
  final String relativePath;
  final String operation;
  final Map<String, dynamic> metadata;
  final DateTime failedAt;
  final int retryCount;
  final String? lastError;
  
  FailedSyncOperation({
    required this.relativePath,
    required this.operation,
    required this.metadata,
    required this.failedAt,
    this.retryCount = 0,
    this.lastError,
  });
  
  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'operation': operation,
    'metadata': metadata,
    'failedAt': failedAt.toIso8601String(),
    'retryCount': retryCount,
    if (lastError != null) 'lastError': lastError,
  };
  
  factory FailedSyncOperation.fromJson(Map<String, dynamic> json) =>
      FailedSyncOperation(
        relativePath: json['relativePath'],
        operation: json['operation'],
        metadata: Map<String, dynamic>.from(json['metadata']),
        failedAt: DateTime.parse(json['failedAt']),
        retryCount: json['retryCount'] ?? 0,
        lastError: json['lastError'],
      );
}

class SyncRetryQueue {
  static const _maxRetries = 5;
  final SharedPreferences _prefs;
  
  SyncRetryQueue(this._prefs);
  
  Future<void> addFailedOperation(FailedSyncOperation operation) async {
    final queue = await getQueue();
    queue.add(operation);
    await _saveQueue(queue);
  }
  
  Future<List<FailedSyncOperation>> getQueue() async {
    final jsonStrings = _prefs.getStringList('sync_retry_queue') ?? [];
    return jsonStrings
        .map((json) => FailedSyncOperation.fromJson(jsonDecode(json)))
        .toList();
  }
  
  Future<void> retryAll(CloudSyncService syncService) async {
    final queue = await getQueue();
    final succeeded = <FailedSyncOperation>[];
    
    for (final operation in queue) {
      if (operation.retryCount >= _maxRetries) {
        continue; // 超过最大重试次数
      }
      
      try {
        switch (operation.operation) {
          case 'upload':
            await syncService.uploadFile(
              operation.relativePath,
              metadata: operation.metadata,
            );
            break;
          case 'download':
            await syncService.downloadFile(
              operation.relativePath,
              metadata: operation.metadata,
            );
            break;
        }
        succeeded.add(operation);
      } catch (e) {
        operation.retryCount++;
        operation.lastError = e.toString();
      }
    }
    
    // 移除成功的操作
    queue.removeWhere((op) => succeeded.contains(op));
    await _saveQueue(queue);
  }
  
  Future<void> _saveQueue(List<FailedSyncOperation> queue) async {
    final jsonStrings = queue
        .map((op) => jsonEncode(op.toJson()))
        .toList();
    await _prefs.setStringList('sync_retry_queue', jsonStrings);
  }
  
  Future<void> clearQueue() async {
    await _prefs.remove('sync_retry_queue');
  }
}
```

---

## 实施优先级

### 立即实施 (本周)

1. ✅ 添加指数退避重试机制
2. ✅ 改进超时配置
3. ✅ 添加网络状态检测

### 短期实施 (1-2周)

4. ⏳ 文件哈希校验
5. ⏳ 改进冲突提示UI
6. ⏳ 增强同步预览

### 长期规划 (1个月)

7. 📋 同步历史记录
8. 📋 失败操作队列
9. 📋 断点续传支持

---

## 测试验证

### 网络测试场景

- [ ] 2G网络下同步10KB文件
- [ ] 网络中断后恢复同步
- [ ] 大文件(>5MB)同步
- [ ] 并发上传/下载
- [ ] 超时场景处理

### 冲突测试场景

- [ ] 同文件双端同时修改
- [ ] 内容相同但时间戳不同
- [ ] 批量冲突处理
- [ ] 手动合并决策

### 性能测试场景

- [ ] 100个文件批量同步
- [ ] 大型目录树扫描
- [ ] 哈希计算性能
- [ ] 内存占用测试

---

## 依赖添加

```yaml
# pubspec.yaml
dependencies:
  connectivity_plus: ^6.0.0
  crypto: ^3.0.3
```

---

## 相关文档

- 云同步服务实现: `lib/services/cloud_sync_service.dart`
- WebDAV服务: `lib/services/webdav_service.dart`
- FTP服务: `lib/services/ftp_service.dart`
- 同步接口: `lib/services/sync_service_interface.dart`
