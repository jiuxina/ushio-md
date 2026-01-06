// ============================================================================
// 工具栏扩展点
// 
// 允许插件在 Markdown 工具栏中添加自定义按钮
// ============================================================================

import 'package:flutter/material.dart';

/// 工具栏按钮扩展
/// 
/// 定义插件添加的工具栏按钮
class ToolbarButtonExtension {
  /// 按钮唯一标识
  final String buttonId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// Material Icon 名称
  final String icon;
  
  /// 按钮提示文字
  final String tooltip;
  
  /// 插入文本的前缀
  final String insertBefore;
  
  /// 插入文本的后缀
  final String insertAfter;
  
  /// 按钮分组（用于分隔符）
  final String? group;
  
  /// 排序优先级（越小越靠前）
  final int priority;

  ToolbarButtonExtension({
    required this.buttonId,
    required this.pluginId,
    required this.icon,
    required this.tooltip,
    this.insertBefore = '',
    this.insertAfter = '',
    this.group,
    this.priority = 100,
  });

  /// 从 JSON 解析
  factory ToolbarButtonExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return ToolbarButtonExtension(
      buttonId: json['id'] as String? ?? '',
      pluginId: pluginId,
      icon: json['icon'] as String? ?? 'extension',
      tooltip: json['tooltip'] as String? ?? '',
      insertBefore: json['insertBefore'] as String? ?? '',
      insertAfter: json['insertAfter'] as String? ?? '',
      group: json['group'] as String?,
      priority: json['priority'] as int? ?? 100,
    );
  }

  /// 获取 IconData
  IconData get iconData {
    // 将字符串图标名称映射到 Material Icons
    return _iconMap[icon] ?? Icons.extension;
  }

  /// 图标名称到 IconData 的映射
  static const Map<String, IconData> _iconMap = {
    'extension': Icons.extension,
    'code': Icons.code,
    'format_quote': Icons.format_quote,
    'link': Icons.link,
    'image': Icons.image,
    'table_chart': Icons.table_chart,
    'checklist': Icons.checklist,
    'functions': Icons.functions,
    'format_list_bulleted': Icons.format_list_bulleted,
    'format_list_numbered': Icons.format_list_numbered,
    'horizontal_rule': Icons.horizontal_rule,
    'format_bold': Icons.format_bold,
    'format_italic': Icons.format_italic,
    'format_strikethrough': Icons.format_strikethrough,
    'subscript': Icons.subscript,
    'superscript': Icons.superscript,
    'highlight': Icons.highlight,
    'keyboard': Icons.keyboard,
    'emoji_emotions': Icons.emoji_emotions,
    'insert_chart': Icons.insert_chart,
    'timeline': Icons.timeline,
    'info': Icons.info,
    'warning': Icons.warning,
    'error': Icons.error,
    'tips_and_updates': Icons.tips_and_updates,
    'note': Icons.note,
    'bookmark': Icons.bookmark,
    'label': Icons.label,
    'tag': Icons.tag,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'thumb_up': Icons.thumb_up,
    'celebration': Icons.celebration,
    'auto_awesome': Icons.auto_awesome,
  };

  /// 执行插入操作
  /// 
  /// [controller] 文本编辑控制器
  void execute(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    
    if (!selection.isValid) {
      // 直接在光标处插入
      final newText = '$insertBefore$insertAfter';
      controller.text = text + newText;
      return;
    }
    
    final before = text.substring(0, selection.start);
    final selected = text.substring(selection.start, selection.end);
    final after = text.substring(selection.end);
    
    final newText = '$before$insertBefore$selected$insertAfter$after';
    controller.text = newText;
    
    // 移动光标到插入内容之后
    final newCursorPosition = selection.start + insertBefore.length + selected.length;
    controller.selection = TextSelection.collapsed(offset: newCursorPosition);
  }
}
