// ============================================================================
// 插件清单数据模型
// 
// 定义插件的元数据结构，包括基本信息、权限、扩展点配置等
// ============================================================================

import 'dart:convert';

/// 插件权限常量
/// 
/// 定义插件可以请求的各种权限类型
class PluginPermission {
  /// 工具栏扩展权限
  static const String toolbar = 'toolbar';
  
  /// 主题扩展权限
  static const String theme = 'theme';
  
  /// 预览渲染扩展权限
  static const String preview = 'preview';
  
  /// 导出格式扩展权限
  static const String export = 'export';
  
  /// 编辑器行为扩展权限
  static const String editor = 'editor';
  
  /// 文件操作扩展权限（危险权限）
  static const String fileActions = 'file_actions';
  
  /// 导航扩展权限
  static const String navigation = 'navigation';
  
  /// 快捷键扩展权限
  static const String shortcuts = 'shortcuts';
  
  /// Widget注入扩展权限
  static const String widgets = 'widgets';
  
  /// 多语言扩展权限
  static const String localization = 'localization';
  
  /// 云服务访问权限（危险权限）
  static const String cloudService = 'cloud';
  
  /// 网络请求权限（危险权限）
  static const String network = 'network';
  
  /// 文件系统访问权限（危险权限）
  static const String fileSystem = 'filesystem';
  
  /// 危险权限列表
  static const List<String> dangerousPermissions = [
    cloudService,
    network,
    fileSystem,
    fileActions,
  ];
  
  /// 检查是否为危险权限
  static bool isDangerous(String permission) {
    return dangerousPermissions.contains(permission);
  }
  
  /// 获取权限的中文描述
  static String getDescription(String permission) {
    switch (permission) {
      case toolbar:
        return '工具栏扩展';
      case theme:
        return '主题配色';
      case preview:
        return '预览渲染';
      case export:
        return '导出格式';
      case editor:
        return '编辑器行为';
      case fileActions:
        return '文件操作（危险）';
      case navigation:
        return '导航扩展';
      case shortcuts:
        return '快捷键绑定';
      case widgets:
        return 'Widget注入';
      case localization:
        return '多语言翻译';
      case cloudService:
        return '云服务访问（危险）';
      case network:
        return '网络请求（危险）';
      case fileSystem:
        return '文件系统（危险）';
      default:
        return permission;
    }
  }
}

/// 插件清单
/// 
/// 定义插件的所有元数据，从 manifest.json 解析而来
class PluginManifest {
  /// 插件唯一标识符（推荐格式：author.plugin-name）
  final String id;
  
  /// 插件显示名称
  final String name;
  
  /// 插件版本号（语义化版本）
  final String version;
  
  /// 插件作者
  final String author;
  
  /// 插件描述
  final String description;
  
  /// 插件图标路径（相对于插件目录）
  final String? iconPath;
  
  /// 作者数字签名（可选，用于验证来源）
  final String? signature;
  
  /// 最低应用版本要求
  final String? minAppVersion;
  
  /// 插件主页或仓库地址
  final String? homepage;
  
  /// 使用说明文件路径（相对于插件目录）
  final String? readmePath;
  
  /// 所需权限列表
  final List<String> permissions;
  
  /// 扩展点配置
  final Map<String, dynamic> extensions;
  
  /// 插件安装路径（运行时填充）
  String? installPath;
  
  /// 是否已启用
  bool isEnabled;

  PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    this.iconPath,
    this.signature,
    this.minAppVersion,
    this.homepage,
    this.readmePath,
    this.permissions = const [],
    this.extensions = const {},
    this.installPath,
    this.isEnabled = false,
  });

  /// 从 JSON 解析插件清单
  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Plugin',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      iconPath: json['icon'] as String?,
      signature: json['signature'] as String?,
      minAppVersion: json['minAppVersion'] as String?,
      homepage: json['homepage'] as String?,
      readmePath: json['readme'] as String?,
      permissions: (json['permissions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      extensions: json['extensions'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 从 JSON 字符串解析
  factory PluginManifest.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return PluginManifest.fromJson(json);
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'author': author,
      'description': description,
      if (iconPath != null) 'icon': iconPath,
      if (readmePath != null) 'readme': readmePath,
      if (signature != null) 'signature': signature,
      if (minAppVersion != null) 'minAppVersion': minAppVersion,
      if (homepage != null) 'homepage': homepage,
      'permissions': permissions,
      'extensions': extensions,
    };
  }

  /// 检查是否包含危险权限
  bool get hasDangerousPermissions {
    return permissions.any(PluginPermission.isDangerous);
  }

  /// 获取所有危险权限
  List<String> get dangerousPermissions {
    return permissions.where(PluginPermission.isDangerous).toList();
  }

  /// 验证清单是否有效
  bool get isValid {
    return id.isNotEmpty && name.isNotEmpty && version.isNotEmpty;
  }

  /// 复制并修改
  PluginManifest copyWith({
    String? id,
    String? name,
    String? version,
    String? author,
    String? description,
    String? iconPath,
    String? readmePath,
    String? signature,
    String? minAppVersion,
    String? homepage,
    List<String>? permissions,
    Map<String, dynamic>? extensions,
    String? installPath,
    bool? isEnabled,
  }) {
    return PluginManifest(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      iconPath: iconPath ?? this.iconPath,
      readmePath: readmePath ?? this.readmePath,
      signature: signature ?? this.signature,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      homepage: homepage ?? this.homepage,
      permissions: permissions ?? this.permissions,
      extensions: extensions ?? this.extensions,
      installPath: installPath ?? this.installPath,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  String toString() {
    return 'PluginManifest(id: $id, name: $name, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PluginManifest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 在线市场插件信息
/// 
/// 用于表示市场中的插件条目
class MarketplacePluginInfo {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String? iconUrl;
  final String? readmeUrl;
  final String downloadUrl;
  final int downloadCount;
  final double rating;
  final DateTime? updatedAt;
  final List<String> permissions;

  MarketplacePluginInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    this.iconUrl,
    this.readmeUrl,
    required this.downloadUrl,
    this.downloadCount = 0,
    this.rating = 0.0,
    this.updatedAt,
    this.permissions = const [],
  });

  factory MarketplacePluginInfo.fromJson(Map<String, dynamic> json) {
    return MarketplacePluginInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      readmeUrl: json['readmeUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      downloadCount: json['downloadCount'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      permissions: (json['permissions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  /// 检查是否包含危险权限
  bool get hasDangerousPermissions {
    return permissions.any(PluginPermission.isDangerous);
  }
}
