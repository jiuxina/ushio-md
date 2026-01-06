// ============================================================================
// 多语言扩展点
// 
// 允许插件提供翻译或添加新的语言支持
// ============================================================================

/// 插件多语言扩展
/// 
/// 定义插件添加的翻译
class PluginLocalizationExtension {
  /// 扩展唯一标识
  final String extensionId;
  
  /// 所属插件ID
  final String pluginId;
  
  /// 支持的语言列表
  final List<String> supportedLocales;
  
  /// 翻译内容
  /// 
  /// 结构: { "locale": { "key": "translation" } }
  final Map<String, Map<String, String>> translations;

  PluginLocalizationExtension({
    required this.extensionId,
    required this.pluginId,
    required this.supportedLocales,
    required this.translations,
  });

  /// 从 JSON 解析
  factory PluginLocalizationExtension.fromJson(Map<String, dynamic> json, String pluginId) {
    final translations = <String, Map<String, String>>{};
    
    final translationsJson = json['translations'] as Map<String, dynamic>?;
    if (translationsJson != null) {
      for (final entry in translationsJson.entries) {
        if (entry.value is Map) {
          translations[entry.key] = Map<String, String>.from(
            (entry.value as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          );
        }
      }
    }
    
    return PluginLocalizationExtension(
      extensionId: json['id'] as String? ?? pluginId,
      pluginId: pluginId,
      supportedLocales: (json['locales'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      translations: translations,
    );
  }

  /// 获取指定语言的翻译
  String? translate(String locale, String key) {
    return translations[locale]?[key];
  }

  /// 获取翻译（带回退）
  String translateWithFallback(String locale, String key, String fallback) {
    return translations[locale]?[key] ?? translations['en']?[key] ?? fallback;
  }

  /// 检查是否支持指定语言
  bool supportsLocale(String locale) {
    return supportedLocales.contains(locale);
  }
}
