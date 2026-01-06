// ============================================================================
// 快捷键扩展点
// 
// 允许插件注册自定义快捷键绑定
// ============================================================================

import 'package:flutter/services.dart';

/// 插件快捷键扩展
/// 
/// 定义插件添加的快捷键绑定
class PluginShortcutExtension {
  /// 快捷键唯一标识
  final String shortcutId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 快捷键描述
  final String description;
  
  /// 按键组合
  final List<String> keys;
  
  /// 触发的动作类型
  final ShortcutActionType actionType;
  
  /// 动作参数
  final Map<String, dynamic> actionParams;

  PluginShortcutExtension({
    required this.shortcutId,
    required this.pluginId,
    required this.description,
    required this.keys,
    required this.actionType,
    this.actionParams = const {},
  });

  /// 从 JSON 解析
  factory PluginShortcutExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginShortcutExtension(
      shortcutId: json['id'] as String? ?? '',
      pluginId: pluginId,
      description: json['description'] as String? ?? '',
      keys: (json['keys'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      actionType: ShortcutActionType.values.firstWhere(
        (t) => t.name == json['actionType'],
        orElse: () => ShortcutActionType.insertText,
      ),
      actionParams: json['actionParams'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 解析按键组合为 Flutter 的 LogicalKeyboardKey
  List<LogicalKeyboardKey> get logicalKeys {
    return keys.map(_parseKey).whereType<LogicalKeyboardKey>().toList();
  }

  /// 解析按键字符串
  static LogicalKeyboardKey? _parseKey(String key) {
    switch (key.toLowerCase()) {
      case 'ctrl':
      case 'control':
        return LogicalKeyboardKey.control;
      case 'shift':
        return LogicalKeyboardKey.shift;
      case 'alt':
        return LogicalKeyboardKey.alt;
      case 'meta':
      case 'cmd':
      case 'command':
        return LogicalKeyboardKey.meta;
      case 'enter':
        return LogicalKeyboardKey.enter;
      case 'tab':
        return LogicalKeyboardKey.tab;
      case 'escape':
      case 'esc':
        return LogicalKeyboardKey.escape;
      case 'space':
        return LogicalKeyboardKey.space;
      case 'backspace':
        return LogicalKeyboardKey.backspace;
      case 'delete':
        return LogicalKeyboardKey.delete;
      default:
        // 单字符
        if (key.length == 1) {
          final code = key.toLowerCase().codeUnitAt(0);
          if (code >= 97 && code <= 122) { // a-z
            return LogicalKeyboardKey(code);
          }
        }
        return null;
    }
  }
}

/// 快捷键动作类型
enum ShortcutActionType {
  /// 插入文本
  insertText,
  /// 包裹选中文本
  wrapSelection,
  /// 执行命令
  executeCommand,
  /// 打开对话框
  openDialog,
  /// 切换模式
  toggleMode,
}
