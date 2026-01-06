// ============================================================================
// 导出格式扩展点
// 
// 允许插件添加自定义导出格式
// ============================================================================

/// 插件导出扩展
/// 
/// 定义插件添加的导出格式
class PluginExportExtension {
  /// 格式唯一标识
  final String formatId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 格式显示名称
  final String formatName;
  
  /// 文件扩展名（不含点）
  final String fileExtension;
  
  /// 导出模板路径（相对于插件目录）
  final String? templatePath;
  
  /// MIME 类型
  final String? mimeType;
  
  /// 是否支持自定义样式
  final bool supportsCustomStyle;

  PluginExportExtension({
    required this.formatId,
    required this.pluginId,
    required this.formatName,
    required this.fileExtension,
    this.templatePath,
    this.mimeType,
    this.supportsCustomStyle = false,
  });

  /// 从 JSON 解析
  factory PluginExportExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    return PluginExportExtension(
      formatId: json['id'] as String? ?? '',
      pluginId: pluginId,
      formatName: json['name'] as String? ?? 'Unknown Format',
      fileExtension: json['extension'] as String? ?? 'txt',
      templatePath: json['template'] as String?,
      mimeType: json['mimeType'] as String?,
      supportsCustomStyle: json['supportsCustomStyle'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': formatId,
      'name': formatName,
      'extension': fileExtension,
      if (templatePath != null) 'template': templatePath,
      if (mimeType != null) 'mimeType': mimeType,
      'supportsCustomStyle': supportsCustomStyle,
    };
  }
}
