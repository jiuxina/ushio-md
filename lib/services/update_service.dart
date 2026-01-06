// ============================================================================
// 更新检查服务
// ============================================================================
// 
// 通过 GitHub API 检查应用是否有新版本。
// 仓库地址：https://github.com/jiuxina/ushio-md
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

/// 安装器抽象
class AppInstaller {
  static const platform = MethodChannel('com.ushiomd/install');
  
  Future<bool?> install(String filePath) async {
    try {
      final result = await platform.invokeMethod<bool>('installApk', {'filePath': filePath});
      return result;
    } catch (e) {
      debugPrint('Install error: $e');
      return false;
    }
  }
}

/// 更新信息
class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String changelog;
  final bool hasUpdate;
  
  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.changelog,
    required this.hasUpdate,
  });
}

/// 更新检查服务
class UpdateService {
  /// GitHub API 地址
  static const String _apiUrl = 'https://api.github.com/repos/jiuxina/ushio-md/releases/latest';
  
  /// 检查更新
  /// 
  /// [currentVersion] 当前应用版本号
  /// 返回 UpdateInfo 或 null（检查失败时）
  static Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 获取最新版本号（去掉 v 前缀）
        final latestVersion = (data['tag_name'] as String).replaceFirst('v', '');
        
        // 获取下载链接（查找 APK 文件）
        String downloadUrl = data['html_url'] ?? '';
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          // 优先查找 arm64 版本
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.contains('arm64') && name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] ?? downloadUrl;
              break;
            }
          }
          // 如果没找到 arm64，查找任意 APK
          if (downloadUrl == data['html_url']) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] ?? downloadUrl;
                break;
              }
            }
          }
        }
        
        // 获取更新日志
        final changelog = data['body'] as String? ?? '暂无更新说明';
        
        // 比较版本号
        final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;
        
        return UpdateInfo(
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          changelog: changelog,
          hasUpdate: hasUpdate,
        );
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  /// 比较版本号
  /// 
  /// 返回值：
  /// - 正数：v1 > v2
  /// - 0：v1 == v2
  /// - 负数：v1 < v2
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    // 补齐长度
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }
    
    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }

  /// 下载并安装更新
  /// 
  /// [url] APK 下载链接
  /// [fileName] 保存的文件名
  /// [onProgress] 进度回调 (0.0 - 1.0)
  static Future<bool> downloadAndInstallUpdate(
    String url, 
    String fileName, {
    Function(double)? onProgress,
    http.Client? client,
    AppInstaller? installer,
  }) async {
    // 优先使用镜像加速
    final proxyUrl = 'https://gh-proxy.org/$url';
    
    // 尝试下载 (优先镜像，失败回退)
    File? apkFile;
    if (await _downloadFile(proxyUrl, fileName, onProgress: onProgress, client: client)) {
      apkFile = await _getLocalFile(fileName);
    } else {
      // 镜像失败，尝试原链接
      debugPrint('镜像下载失败，尝试原始链接...');
      if (await _downloadFile(url, fileName, onProgress: onProgress, client: client)) {
        apkFile = await _getLocalFile(fileName);
      }
    }
    
    if (apkFile != null && apkFile.existsSync()) {
      // 安装
      debugPrint('开始安装: ${apkFile.path}');
      final appInstaller = installer ?? AppInstaller();
      final result = await appInstaller.install(apkFile.path);
      return result == true;
    }
    
    return false;
  }

  /// 获取本地临时文件
  static Future<File> _getLocalFile(String fileName) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/$fileName');
  }

  /// 下载文件内部实现
  static Future<bool> _downloadFile(
    String url, 
    String fileName, {
    Function(double)? onProgress,
    http.Client? client,
  }) async {
    try {
      final finalClient = client ?? http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await finalClient.send(request).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        
        final file = await _getLocalFile(fileName);
        final sink = file.openWrite();
        
        await response.stream.listen(
          (List<int> chunk) {
            receivedBytes += chunk.length;
            sink.add(chunk);
            if (totalBytes > 0 && onProgress != null) {
              onProgress(receivedBytes / totalBytes);
            }
          },
          onDone: () async {
            await sink.close();
          },
          onError: (e) {
            debugPrint('下载流错误: $e');
            sink.close();
          },
          cancelOnError: true,
        ).asFuture();
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('下载异常: $url, $e');
      return false;
    }
  }
}
