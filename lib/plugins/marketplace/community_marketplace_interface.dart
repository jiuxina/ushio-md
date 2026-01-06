// ============================================================================
// 社区插件市场接口
// 
// 预留接口，供未来"在线插件市场插件"使用
// 用户可以导入实现此接口的插件来添加社区市场支持
// ============================================================================

import '../plugin_manifest.dart';

/// 社区市场接口
/// 
/// 抽象接口，定义社区市场必须实现的方法
abstract class CommunityMarketplaceInterface {
  /// 市场名称
  String get marketplaceName;
  
  /// 市场 URL
  String get marketplaceUrl;
  
  /// 市场图标 URL
  String? get iconUrl;
  
  /// 市场描述
  String get description;
  
  /// 获取插件列表
  Future<List<MarketplacePluginInfo>> fetchPlugins();
  
  /// 搜索插件
  Future<List<MarketplacePluginInfo>> searchPlugins(String query);
  
  /// 获取插件详情
  Future<MarketplacePluginInfo?> getPluginInfo(String pluginId);
  
  /// 获取插件下载 URL
  String getDownloadUrl(String pluginId);
}

/// 社区市场注册表
/// 
/// 管理已注册的社区市场
class CommunityMarketplaceRegistry {
  static final CommunityMarketplaceRegistry _instance = CommunityMarketplaceRegistry._internal();
  
  factory CommunityMarketplaceRegistry() => _instance;
  
  CommunityMarketplaceRegistry._internal();
  
  /// 已注册的社区市场
  final List<CommunityMarketplaceInterface> _marketplaces = [];
  
  /// 获取所有已注册的市场
  List<CommunityMarketplaceInterface> get marketplaces => List.unmodifiable(_marketplaces);
  
  /// 注册社区市场
  void registerMarketplace(CommunityMarketplaceInterface marketplace) {
    if (!_marketplaces.any((m) => m.marketplaceUrl == marketplace.marketplaceUrl)) {
      _marketplaces.add(marketplace);
    }
  }
  
  /// 注销社区市场
  void unregisterMarketplace(String marketplaceUrl) {
    _marketplaces.removeWhere((m) => m.marketplaceUrl == marketplaceUrl);
  }
  
  /// 清除所有市场
  void clearAll() {
    _marketplaces.clear();
  }
}

/// 社区市场占位页面信息
/// 
/// 当没有社区市场可用时显示
class CommunityMarketplacePlaceholder {
  static const String title = '社区市场';
  static const String message = '社区市场功能即将推出\n\n'
      '您可以通过安装"在线插件市场插件"来添加社区市场支持。\n\n'
      '敬请期待！';
  static const String comingSoonLabel = '即将推出';
}
