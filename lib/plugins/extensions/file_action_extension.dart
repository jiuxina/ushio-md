// ============================================================================
// 文件操作扩展点
// 
// 允许插件在文件上下文菜单中添加自定义操作
// ============================================================================

import 'package:flutter/material.dart';

/// 插件文件操作扩展
/// 
/// 定义插件添加的文件操作
class PluginFileActionExtension {
  /// 操作唯一标识
  final String actionId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 操作显示名称
  final String actionName;
  
  /// 操作图标
  final String icon;
  
  /// 操作类型
  final FileActionType actionType;
  
  /// 支持的文件类型（扩展名列表，空表示所有）
  final List<String> supportedExtensions;
  
  /// 操作脚本/命令（根据 actionType 解释）
  final String? script;

  PluginFileActionExtension({
    required this.actionId,
    required this.pluginId,
    required this.actionName,
    required this.icon,
    required this.actionType,
    this.supportedExtensions = const [],
    this.script,
  });

  /// 从 JSON 解析
  factory PluginFileActionExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginFileActionExtension(
      actionId: json['id'] as String? ?? '',
      pluginId: pluginId,
      actionName: json['name'] as String? ?? 'Unknown Action',
      icon: json['icon'] as String? ?? 'extension',
      actionType: FileActionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => FileActionType.custom,
      ),
      supportedExtensions: (json['extensions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      script: json['script'] as String?,
    );
  }

  /// 获取图标
  IconData get iconData {
    return _iconMap[icon] ?? Icons.extension;
  }

  /// 图标映射
  static const Map<String, IconData> _iconMap = {
    'share': Icons.share,
    'copy': Icons.copy,
    'delete': Icons.delete,
    'edit': Icons.edit,
    'transform': Icons.transform,
    'upload': Icons.upload,
    'download': Icons.download,
    'compress': Icons.compress,
    'expand': Icons.expand,
    'extension': Icons.extension,
  };

  /// 检查是否支持指定文件
  bool supportsFile(String filePath) {
    if (supportedExtensions.isEmpty) return true;
    final ext = filePath.split('.').last.toLowerCase();
    return supportedExtensions.any((e) => e.toLowerCase() == ext);
  }
}

/// 文件操作类型
enum FileActionType {
  /// 自定义操作
  custom,
  /// 转换操作
  transform,
  /// 分享操作
  share,
  /// 上传操作
  upload,
}
