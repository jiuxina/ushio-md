// ============================================================================
// 导航扩展点
// 
// 允许插件添加自定义导航项和标签页
// ============================================================================

import 'package:flutter/material.dart';

/// 插件导航扩展
/// 
/// 定义插件添加的导航项
class PluginNavigationExtension {
  /// 导航项唯一标识
  final String navId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 导航项标题
  final String title;
  
  /// 导航项图标
  final String icon;
  
  /// 导航位置
  final NavigationPosition position;
  
  /// 内容类型
  final NavigationContentType contentType;
  
  /// 内容路径（相对于插件目录）
  final String? contentPath;
  
  /// 排序优先级
  final int priority;

  PluginNavigationExtension({
    required this.navId,
    required this.pluginId,
    required this.title,
    required this.icon,
    this.position = NavigationPosition.tab,
    this.contentType = NavigationContentType.webview,
    this.contentPath,
    this.priority = 100,
  });

  /// 从 JSON 解析
  factory PluginNavigationExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginNavigationExtension(
      navId: json['id'] as String? ?? '',
      pluginId: pluginId,
      title: json['title'] as String? ?? 'Unknown',
      icon: json['icon'] as String? ?? 'extension',
      position: NavigationPosition.values.firstWhere(
        (p) => p.name == json['position'],
        orElse: () => NavigationPosition.tab,
      ),
      contentType: NavigationContentType.values.firstWhere(
        (t) => t.name == json['contentType'],
        orElse: () => NavigationContentType.webview,
      ),
      contentPath: json['contentPath'] as String?,
      priority: json['priority'] as int? ?? 100,
    );
  }

  /// 获取图标
  IconData get iconData {
    return _iconMap[icon] ?? Icons.extension;
  }

  static const Map<String, IconData> _iconMap = {
    'home': Icons.home,
    'folder': Icons.folder,
    'settings': Icons.settings,
    'info': Icons.info,
    'help': Icons.help,
    'extension': Icons.extension,
    'dashboard': Icons.dashboard,
    'analytics': Icons.analytics,
    'bookmark': Icons.bookmark,
    'star': Icons.star,
  };
}

/// 导航位置
enum NavigationPosition {
  /// 底部标签栏
  tab,
  /// 侧边栏
  drawer,
  /// 设置页面
  settings,
}

/// 导航内容类型
enum NavigationContentType {
  /// WebView 内容
  webview,
  /// Markdown 内容
  markdown,
  /// 列表内容
  list,
}
