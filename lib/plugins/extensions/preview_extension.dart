// ============================================================================
// 预览渲染扩展点
// 
// 允许插件自定义 Markdown 预览的样式和行为
// ============================================================================

/// 插件预览扩展
/// 
/// 定义插件添加的预览样式
class PluginPreviewExtension {
  /// 扩展唯一标识
  final String extensionId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 自定义 CSS 样式
  final String? customCss;
  
  /// 代码高亮主题名称
  final String? codeTheme;
  
  /// 是否启用数学公式渲染
  final bool? enableMath;
  
  /// 是否启用 Mermaid 图表
  final bool? enableMermaid;
  
  /// 自定义字体
  final String? fontFamily;
  
  /// 自定义行高
  final double? lineHeight;

  PluginPreviewExtension({
    required this.extensionId,
    required this.pluginId,
    this.customCss,
    this.codeTheme,
    this.enableMath,
    this.enableMermaid,
    this.fontFamily,
    this.lineHeight,
  });

  /// 从 JSON 解析
  factory PluginPreviewExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginPreviewExtension(
      extensionId: json['id'] as String? ?? pluginId,
      pluginId: pluginId,
      customCss: json['css'] as String?,
      codeTheme: json['codeTheme'] as String?,
      enableMath: json['enableMath'] as bool?,
      enableMermaid: json['enableMermaid'] as bool?,
      fontFamily: json['fontFamily'] as String?,
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': extensionId,
      if (customCss != null) 'css': customCss,
      if (codeTheme != null) 'codeTheme': codeTheme,
      if (enableMath != null) 'enableMath': enableMath,
      if (enableMermaid != null) 'enableMermaid': enableMermaid,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (lineHeight != null) 'lineHeight': lineHeight,
    };
  }
}
