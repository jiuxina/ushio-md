// ============================================================================
// Widget 注入扩展点
// 
// 允许插件在应用的特定位置注入自定义 Widget
// ============================================================================

import 'package:flutter/material.dart';

/// 插件 Widget 注入扩展
/// 
/// 定义插件注入的 Widget 配置
class PluginWidgetExtension {
  /// Widget 唯一标识
  final String widgetId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 注入位置
  final WidgetInjectionPoint injectionPoint;
  
  /// Widget 类型
  final WidgetType widgetType;
  
  /// 配置参数
  final Map<String, dynamic> config;
  
  /// 内容路径（相对于插件目录）
  final String? contentPath;
  
  /// 排序优先级
  final int priority;

  PluginWidgetExtension({
    required this.widgetId,
    required this.pluginId,
    required this.injectionPoint,
    required this.widgetType,
    this.config = const {},
    this.contentPath,
    this.priority = 100,
  });

  /// 从 JSON 解析
  factory PluginWidgetExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginWidgetExtension(
      widgetId: json['id'] as String? ?? '',
      pluginId: pluginId,
      injectionPoint: WidgetInjectionPoint.values.firstWhere(
        (p) => p.name == json['injectionPoint'],
        orElse: () => WidgetInjectionPoint.homeTab,
      ),
      widgetType: WidgetType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => WidgetType.banner,
      ),
      config: json['config'] as Map<String, dynamic>? ?? {},
      contentPath: json['contentPath'] as String?,
      priority: json['priority'] as int? ?? 100,
    );
  }

  /// 构建 Widget
  Widget build(BuildContext context) {
    switch (widgetType) {
      case WidgetType.banner:
        return _buildBanner(context);
      case WidgetType.card:
        return _buildCard(context);
      case WidgetType.button:
        return _buildButton(context);
      case WidgetType.text:
        return _buildText(context);
    }
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (config['icon'] != null)
            Icon(
              Icons.extension,
              color: Theme.of(context).colorScheme.primary,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (config['title'] != null)
                  Text(
                    config['title'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (config['subtitle'] != null)
                  Text(
                    config['subtitle'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (config['title'] != null)
              Text(
                config['title'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (config['content'] != null)
              Text(config['content'] as String),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    return FilledButton(
      onPressed: () {
        // TODO: 执行插件定义的动作
      },
      child: Text(config['label'] as String? ?? 'Button'),
    );
  }

  Widget _buildText(BuildContext context) {
    return Text(config['text'] as String? ?? '');
  }
}

/// Widget 注入位置
enum WidgetInjectionPoint {
  /// 首页标签
  homeTab,
  /// 编辑器顶部
  editorTop,
  /// 编辑器底部
  editorBottom,
  /// 设置页面
  settingsPage,
  /// 文件列表顶部
  fileListTop,
}

/// Widget 类型
enum WidgetType {
  /// 横幅
  banner,
  /// 卡片
  card,
  /// 按钮
  button,
  /// 文本
  text,
}
