/// ============================================================================
/// 更新检查服务
/// ============================================================================
/// 
/// 通过 GitHub API 检查应用是否有新版本。
/// 仓库地址：https://github.com/jiuxina/ushio-md
/// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

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
    while (parts1.length < 3) parts1.add(0);
    while (parts2.length < 3) parts2.add(0);
    
    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }
}
