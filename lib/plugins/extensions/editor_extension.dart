// ============================================================================
// 编辑器行为扩展点
// 
// 允许插件修改编辑器的行为和功能
// ============================================================================

/// 插件编辑器扩展
/// 
/// 定义插件添加的编辑器行为配置
class PluginEditorExtension {
  /// 扩展唯一标识
  final String extensionId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 自动补全规则
  final List<AutoCompleteRule> autoCompleteRules;
  
  /// 自定义语法高亮
  final Map<String, String>? syntaxPatterns;
  
  /// 缩进大小
  final int? indentSize;
  
  /// 是否使用制表符
  final bool? useTabs;
  
  /// 是否启用自动换行
  final bool? wordWrap;
  
  /// 是否显示行号
  final bool? showLineNumbers;

  PluginEditorExtension({
    required this.extensionId,
    required this.pluginId,
    this.autoCompleteRules = const [],
    this.syntaxPatterns,
    this.indentSize,
    this.useTabs,
    this.wordWrap,
    this.showLineNumbers,
  });

  /// 从 JSON 解析
  factory PluginEditorExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginEditorExtension(
      extensionId: json['id'] as String? ?? pluginId,
      pluginId: pluginId,
      autoCompleteRules: (json['autoComplete'] as List<dynamic>?)
          ?.map((e) => AutoCompleteRule.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      syntaxPatterns: json['syntaxPatterns'] != null
          ? Map<String, String>.from(json['syntaxPatterns'] as Map)
          : null,
      indentSize: json['indentSize'] as int?,
      useTabs: json['useTabs'] as bool?,
      wordWrap: json['wordWrap'] as bool?,
      showLineNumbers: json['showLineNumbers'] as bool?,
    );
  }
}

/// 自动补全规则
class AutoCompleteRule {
  /// 触发字符
  final String trigger;
  
  /// 补全内容
  final String completion;
  
  /// 光标偏移（相对于补全内容末尾）
  final int cursorOffset;

  AutoCompleteRule({
    required this.trigger,
    required this.completion,
    this.cursorOffset = 0,
  });

  /// 从 JSON 解析
  factory AutoCompleteRule.fromJson(Map<String, dynamic> json) {
    return AutoCompleteRule(
      trigger: json['trigger'] as String? ?? '',
      completion: json['completion'] as String? ?? '',
      cursorOffset: json['cursorOffset'] as int? ?? 0,
    );
  }
}
