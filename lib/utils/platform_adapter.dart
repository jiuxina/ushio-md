import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// 平台适配工具类
class PlatformAdapter {
  /// 获取默认的工作区基础路径
  static Future<String> getDefaultWorkspaceBasePath() async {
    if (Platform.isAndroid) {
      // Android: 使用环境变量获取外部存储根目录，然后构建 Documents 路径
      // 这样比硬编码更可靠，兼容多用户和多存储分区设备
      final externalStorage = Platform.environment['EXTERNAL_STORAGE'];
      if (externalStorage != null && externalStorage.isNotEmpty) {
        return '$externalStorage${Platform.pathSeparator}Documents';
      }
      // 回退到硬编码路径（兼容性）
      return '/storage/emulated/0/Documents';
    } else if (Platform.isWindows) {
      // Windows: 使用用户文档目录
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    } else if (Platform.isMacOS) {
      // macOS: 使用用户文档目录
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    } else if (Platform.isLinux) {
      // Linux: 使用用户文档目录
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    } else if (Platform.isIOS) {
      // iOS: 使用应用文档目录
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    }

    // 默认回退到应用文档目录
    final docsDir = await getApplicationDocumentsDirectory();
    return docsDir.path;
  }

  /// 获取平台名称
  static String getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Unknown';
  }

  /// 检查是否是移动平台
  static bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 检查是否是桌面平台
  static bool isDesktop() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// 获取应用数据目录
  static Future<String> getAppDataDirectory() async {
    if (Platform.isAndroid) {
      // Android: 使用外部存储目录
      final dir = await getExternalStorageDirectory();
      return dir?.path ?? (await getApplicationDocumentsDirectory()).path;
    } else {
      // 其他平台: 使用应用文档目录
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
  }

  /// 获取临时目录
  static Future<String> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  /// 获取下载目录路径(如果可用)
  static String? getDownloadsDirectoryPath() {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    } else if (Platform.isWindows) {
      // Windows: 通常在用户目录下的 Downloads
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        return '$home\\Downloads';
      }
    } else if (Platform.isLinux) {
      // Linux: 通常在用户目录下的 Downloads
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Downloads';
      }
    } else if (Platform.isMacOS) {
      // macOS: 通常在用户目录下的 Downloads
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Downloads';
      }
    }
    return null;
  }

  /// 获取桌面目录路径(如果可用)
  static String? getDesktopDirectoryPath() {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        return '$home\\Desktop';
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Desktop';
      }
    }
    return null;
  }

  /// 规范化路径分隔符
  static String normalizePath(String path) {
    return path
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
  }

  /// 获取文件名(不含路径)
  static String getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  /// 获取父目录路径
  static String getParentPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    if (parts.length <= 1) return path;
    return parts.sublist(0, parts.length - 1).join(Platform.pathSeparator);
  }
}
