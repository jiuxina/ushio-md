// ============================================================================
// 官方插件市场服务
// 
// 从 GitHub 仓库获取官方插件列表：
// https://github.com/jiuxina/ushio-md-plugins
// ============================================================================

import 'dart:convert';
import 'dart:io';
import '../plugin_manifest.dart';

/// 官方插件市场
/// 
/// 基于 GitHub 仓库的插件市场实现
/// 优先使用镜像加速访问 GitHub 资源
class OfficialMarketplace {
  /// GitHub 仓库 Raw 文件基础 URL
  static const String _baseUrl = 'https://raw.githubusercontent.com/jiuxina/ushio-md-plugins/main';
  
  /// 镜像加速 URL 前缀列表（按优先级排序）
  static const List<String> _proxyPrefixes = [
    'https://gh-proxy.org/',
    'https://ghproxy.com/',
    'https://mirror.ghproxy.com/',
  ];
  
  /// 插件索引文件路径
  static const String _indexPath = '/plugins.json';
  
  /// 缓存的插件列表
  List<MarketplacePluginInfo>? _cachedPlugins;
  
  /// 缓存时间
  DateTime? _cacheTime;
  
  /// 缓存有效期（分钟）
  static const int _cacheDurationMinutes = 30;

  /// 获取插件列表
  /// 
  /// [forceRefresh] 是否强制刷新缓存
  Future<List<MarketplacePluginInfo>> fetchPlugins({bool forceRefresh = false}) async {
    // 检查缓存
    if (!forceRefresh && _cachedPlugins != null && _cacheTime != null) {
      final cacheAge = DateTime.now().difference(_cacheTime!);
      if (cacheAge.inMinutes < _cacheDurationMinutes) {
        return _cachedPlugins!;
      }
    }
    
    final originalUrl = '$_baseUrl$_indexPath';
    
    // 尝试镜像源，失败则回退到原始链接
    String? body;
    String? lastError;
    
    // 先尝试所有镜像源
    for (final prefix in _proxyPrefixes) {
      try {
        body = await _fetchUrl('$prefix$originalUrl');
        if (body != null) break;
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }
    
    // 镜像都失败，尝试原始链接
    if (body == null) {
      try {
        body = await _fetchUrl(originalUrl);
      } catch (e) {
        throw MarketplaceException('获取插件列表失败：${lastError ?? e.toString()}');
      }
    }
    
    if (body == null) {
      throw MarketplaceException('获取插件列表失败：无法连接到服务器');
    }
    
    final json = jsonDecode(body);
    
    if (json is! Map<String, dynamic>) {
      throw MarketplaceException('插件索引格式无效');
    }
    
    final pluginsJson = json['plugins'] as List<dynamic>?;
    if (pluginsJson == null) {
      throw MarketplaceException('插件索引中未找到 plugins 字段');
    }
    
    _cachedPlugins = pluginsJson
        .map((e) => MarketplacePluginInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    _cacheTime = DateTime.now();
    
    return _cachedPlugins!;
  }
  
  /// 从 URL 获取内容
  Future<String?> _fetchUrl(String url) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
      return null;
    } finally {
      httpClient.close();
    }
  }

  /// 获取插件下载 URL
  String getDownloadUrl(String pluginId) {
    return '$_baseUrl/plugins/$pluginId.zip';
  }

  /// 搜索插件
  Future<List<MarketplacePluginInfo>> searchPlugins(String query) async {
    final plugins = await fetchPlugins();
    final lowerQuery = query.toLowerCase();
    
    return plugins.where((plugin) {
      return plugin.name.toLowerCase().contains(lowerQuery) ||
             plugin.description.toLowerCase().contains(lowerQuery) ||
             plugin.author.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 获取插件详情
  Future<MarketplacePluginInfo?> getPluginInfo(String pluginId) async {
    final plugins = await fetchPlugins();
    try {
      return plugins.firstWhere((p) => p.id == pluginId);
    } catch (e) {
      return null;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cachedPlugins = null;
    _cacheTime = null;
  }
}

/// 市场异常
class MarketplaceException implements Exception {
  final String message;
  
  MarketplaceException(this.message);
  
  @override
  String toString() => 'MarketplaceException: $message';
}
