// ============================================================================
// 插件加载器
// 
// 负责插件的加载、安装、卸载等操作：
// - 解析插件 ZIP 包
// - 验证插件清单
// - 解压到应用插件目录
// - 支持热更新
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'plugin_manifest.dart';

/// 插件加载器
/// 
/// 处理插件的安装、加载和卸载
class PluginLoader {
  /// 插件安装目录名
  static const String pluginsDirectoryName = 'plugins';
  
  /// 获取插件安装目录
  static Future<Directory> getPluginsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pluginsDir = Directory('${appDir.path}/$pluginsDirectoryName');
    if (!await pluginsDir.exists()) {
      await pluginsDir.create(recursive: true);
    }
    return pluginsDir;
  }

  /// 从 ZIP 文件安装插件
  /// 
  /// [zipFile] 插件 ZIP 文件
  /// 返回安装成功的插件清单，失败则抛出异常
  static Future<PluginManifest> installFromZip(File zipFile) async {
    // 读取 ZIP 文件
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // 查找 manifest.json
    final manifestFile = archive.files.firstWhere(
      (file) => file.name == 'manifest.json' || file.name.endsWith('/manifest.json'),
      orElse: () => throw PluginLoadException('插件包中未找到 manifest.json'),
    );
    
    // 解析清单
    final manifestContent = utf8.decode(manifestFile.content as List<int>);
    final manifest = PluginManifest.fromJsonString(manifestContent);
    
    // 验证清单
    if (!manifest.isValid) {
      throw PluginLoadException('插件清单无效：缺少必要字段');
    }
    
    // 获取安装目录
    final pluginsDir = await getPluginsDirectory();
    final pluginDir = Directory('${pluginsDir.path}/${manifest.id}');
    
    // 如果已存在，先删除
    if (await pluginDir.exists()) {
      await pluginDir.delete(recursive: true);
    }
    await pluginDir.create(recursive: true);
    
    // 解压所有文件
    for (final file in archive.files) {
      final filename = file.name;
      if (file.isFile) {
        final outputFile = File('${pluginDir.path}/$filename');
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
      }
    }
    
    // 更新清单的安装路径
    return manifest.copyWith(installPath: pluginDir.path);
  }

  /// 从 URL 下载并安装插件
  /// 
  /// [downloadUrl] 插件下载地址
  static Future<PluginManifest> installFromUrl(String downloadUrl) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw PluginLoadException('下载失败：HTTP ${response.statusCode}');
      }
      
      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/plugin_download_${DateTime.now().millisecondsSinceEpoch}.zip');
      
      // 写入文件
      final sink = tempFile.openWrite();
      await response.pipe(sink);
      await sink.close();
      
      // 安装
      final manifest = await installFromZip(tempFile);
      
      // 清理临时文件
      await tempFile.delete();
      
      return manifest;
    } finally {
      httpClient.close();
    }
  }

  /// 加载所有已安装的插件
  static Future<List<PluginManifest>> loadInstalledPlugins() async {
    final pluginsDir = await getPluginsDirectory();
    final plugins = <PluginManifest>[];
    
    if (!await pluginsDir.exists()) {
      return plugins;
    }
    
    await for (final entity in pluginsDir.list()) {
      if (entity is Directory) {
        try {
          final manifest = await loadPluginManifest(entity);
          if (manifest != null) {
            plugins.add(manifest);
          }
        } catch (e) {
          // 跳过无效插件
          continue;
        }
      }
    }
    
    return plugins;
  }

  /// 加载单个插件的清单
  static Future<PluginManifest?> loadPluginManifest(Directory pluginDir) async {
    final manifestFile = File('${pluginDir.path}/manifest.json');
    
    if (!await manifestFile.exists()) {
      return null;
    }
    
    try {
      final content = await manifestFile.readAsString();
      final manifest = PluginManifest.fromJsonString(content);
      return manifest.copyWith(installPath: pluginDir.path);
    } catch (e) {
      return null;
    }
  }

  /// 卸载插件
  static Future<void> uninstallPlugin(String pluginId) async {
    final pluginsDir = await getPluginsDirectory();
    final pluginDir = Directory('${pluginsDir.path}/$pluginId');
    
    if (await pluginDir.exists()) {
      await pluginDir.delete(recursive: true);
    }
  }

  /// 获取插件图标路径
  static Future<String?> getPluginIconPath(PluginManifest manifest) async {
    if (manifest.iconPath == null || manifest.installPath == null) {
      return null;
    }
    
    final iconFile = File('${manifest.installPath}/${manifest.iconPath}');
    if (await iconFile.exists()) {
      return iconFile.path;
    }
    
    return null;
  }

  /// 读取插件资源文件
  static Future<String?> readPluginResource(PluginManifest manifest, String resourcePath) async {
    if (manifest.installPath == null) return null;
    
    final file = File('${manifest.installPath}/$resourcePath');
    if (await file.exists()) {
      return await file.readAsString();
    }
    
    return null;
  }
}

/// 插件加载异常
class PluginLoadException implements Exception {
  final String message;
  
  PluginLoadException(this.message);
  
  @override
  String toString() => 'PluginLoadException: $message';
}
