// ============================================================================
// 插件状态管理 Provider
// 
// 管理插件的全局状态：
// - 已安装插件列表
// - 已启用插件列表
// - 插件安装/卸载/启用/禁用操作
// - 热更新支持
// - 持久化状态
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../plugins/plugin_manifest.dart';
import '../plugins/plugin_loader.dart';
import '../plugins/plugin_security.dart';
import '../plugins/extensions/toolbar_extension.dart';
import '../plugins/extensions/theme_extension.dart';
import '../plugins/extensions/preview_extension.dart';
import '../plugins/extensions/navigation_extension.dart';
import '../plugins/extensions/file_action_extension.dart';
import '../plugins/extensions/export_extension.dart';
import '../plugins/extensions/editor_extension.dart';
import '../plugins/extensions/widget_extension.dart';
import '../plugins/extensions/shortcut_extension.dart';
import '../plugins/extensions/localization_extension.dart';

/// 插件状态管理器
/// 
/// 使用 ChangeNotifier 支持热更新
class PluginProvider extends ChangeNotifier {
  /// SharedPreferences 键名
  static const String _enabledPluginsKey = 'enabled_plugins';
  static const String _networkAccessAllowedKey = 'network_access_allowed';

  /// 已安装的插件列表
  List<PluginManifest> _installedPlugins = [];
  
  /// 已启用的插件ID集合
  Set<String> _enabledPluginIds = {};
  
  /// 是否已初始化
  bool _isInitialized = false;
  
  /// 是否正在加载
  bool _isLoading = false;
  
  /// 用户是否已允许联网
  bool _networkAccessAllowed = false;

  /// 获取已安装插件列表
  List<PluginManifest> get installedPlugins => List.unmodifiable(_installedPlugins);
  
  /// 获取已启用的插件列表
  List<PluginManifest> get enabledPlugins => 
      _installedPlugins.where((p) => _enabledPluginIds.contains(p.id)).toList();
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 是否正在加载
  bool get isLoading => _isLoading;
  
  /// 已安装插件数量
  int get installedCount => _installedPlugins.length;
  
  /// 已启用插件数量
  int get enabledCount => _enabledPluginIds.length;
  
  /// 是否已允许联网
  bool get networkAccessAllowed => _networkAccessAllowed;

  /// 初始化插件系统
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // 加载已保存的启用状态
      final prefs = await SharedPreferences.getInstance();
      final enabledIds = prefs.getStringList(_enabledPluginsKey) ?? [];
      _enabledPluginIds = enabledIds.toSet();
      _networkAccessAllowed = prefs.getBool(_networkAccessAllowedKey) ?? false;
      
      // 加载已安装的插件
      _installedPlugins = await PluginLoader.loadInstalledPlugins();
      
      // 更新插件的启用状态
      for (var i = 0; i < _installedPlugins.length; i++) {
        final plugin = _installedPlugins[i];
        _installedPlugins[i] = plugin.copyWith(
          isEnabled: _enabledPluginIds.contains(plugin.id),
        );
      }
      
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 从本地 ZIP 文件安装插件
  Future<PluginInstallResult> installFromLocalFile(BuildContext context) async {
    try {
      // 选择文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      
      if (result == null || result.files.isEmpty) {
        return PluginInstallResult(success: false, message: '未选择文件');
      }
      
      final filePath = result.files.first.path;
      if (filePath == null) {
        return PluginInstallResult(success: false, message: '无法读取文件路径');
      }
      
      _isLoading = true;
      notifyListeners();
      
      // 安装插件
      final manifest = await PluginLoader.installFromZip(File(filePath));
      
      // 检查危险权限
      if (manifest.hasDangerousPermissions && context.mounted) {
        final confirmed = await PluginSecurity.showDangerousPermissionWarning(
          context,
          manifest,
        );
        
        if (!confirmed) {
          // 用户取消，卸载插件
          await PluginLoader.uninstallPlugin(manifest.id);
          return PluginInstallResult(success: false, message: '用户取消安装');
        }
      }
      
      // 更新列表
      _installedPlugins.removeWhere((p) => p.id == manifest.id);
      _installedPlugins.add(manifest);
      
      _isLoading = false;
      notifyListeners();
      
      return PluginInstallResult(
        success: true,
        message: '插件 "${manifest.name}" 安装成功',
        manifest: manifest,
      );
    } on PluginLoadException catch (e) {
      _isLoading = false;
      notifyListeners();
      return PluginInstallResult(success: false, message: e.message);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return PluginInstallResult(success: false, message: '安装失败：$e');
    }
  }

  /// 从 URL 安装插件
  Future<PluginInstallResult> installFromUrl(BuildContext context, String url) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final manifest = await PluginLoader.installFromUrl(url);
      
      // 检查危险权限
      if (manifest.hasDangerousPermissions && context.mounted) {
        final confirmed = await PluginSecurity.showDangerousPermissionWarning(
          context,
          manifest,
        );
        
        if (!confirmed) {
          await PluginLoader.uninstallPlugin(manifest.id);
          return PluginInstallResult(success: false, message: '用户取消安装');
        }
      }
      
      _installedPlugins.removeWhere((p) => p.id == manifest.id);
      _installedPlugins.add(manifest);
      
      _isLoading = false;
      notifyListeners();
      
      return PluginInstallResult(
        success: true,
        message: '插件 "${manifest.name}" 安装成功',
        manifest: manifest,
      );
    } on PluginLoadException catch (e) {
      _isLoading = false;
      notifyListeners();
      return PluginInstallResult(success: false, message: e.message);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return PluginInstallResult(success: false, message: '安装失败：$e');
    }
  }

  /// 启用插件
  Future<bool> enablePlugin(BuildContext context, String pluginId) async {
    final plugin = _installedPlugins.firstWhere(
      (p) => p.id == pluginId,
      orElse: () => throw Exception('插件不存在'),
    );
    
    // 检查危险权限
    if (plugin.hasDangerousPermissions && context.mounted) {
      final confirmed = await PluginSecurity.showDangerousPermissionWarning(
        context,
        plugin,
      );
      
      if (!confirmed) return false;
    }
    
    _enabledPluginIds.add(pluginId);
    
    // 更新插件状态
    final index = _installedPlugins.indexWhere((p) => p.id == pluginId);
    if (index >= 0) {
      _installedPlugins[index] = _installedPlugins[index].copyWith(isEnabled: true);
    }
    
    await _saveEnabledPlugins();
    notifyListeners();
    
    return true;
  }

  /// 禁用插件
  Future<void> disablePlugin(String pluginId) async {
    _enabledPluginIds.remove(pluginId);
    
    final index = _installedPlugins.indexWhere((p) => p.id == pluginId);
    if (index >= 0) {
      _installedPlugins[index] = _installedPlugins[index].copyWith(isEnabled: false);
    }
    
    await _saveEnabledPlugins();
    notifyListeners();
  }

  /// 卸载插件
  Future<void> uninstallPlugin(String pluginId) async {
    await PluginLoader.uninstallPlugin(pluginId);
    _installedPlugins.removeWhere((p) => p.id == pluginId);
    _enabledPluginIds.remove(pluginId);
    
    await _saveEnabledPlugins();
    notifyListeners();
  }

  /// 检查插件是否已启用
  bool isPluginEnabled(String pluginId) {
    return _enabledPluginIds.contains(pluginId);
  }

  /// 设置联网访问权限
  Future<void> setNetworkAccessAllowed(bool allowed) async {
    _networkAccessAllowed = allowed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_networkAccessAllowedKey, allowed);
    notifyListeners();
  }

  /// 保存启用的插件列表
  Future<void> _saveEnabledPlugins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledPluginsKey, _enabledPluginIds.toList());
  }

  /// 刷新插件列表
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _installedPlugins = await PluginLoader.loadInstalledPlugins();
      
      for (var i = 0; i < _installedPlugins.length; i++) {
        final plugin = _installedPlugins[i];
        _installedPlugins[i] = plugin.copyWith(
          isEnabled: _enabledPluginIds.contains(plugin.id),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // 扩展点聚合方法
  // ============================================================================

  /// 获取所有已启用插件的工具栏扩展
  List<ToolbarButtonExtension> getToolbarExtensions() {
    final extensions = <ToolbarButtonExtension>[];
    
    for (final plugin in enabledPlugins) {
      final toolbarConfig = plugin.extensions['toolbar'];
      if (toolbarConfig != null && toolbarConfig is List) {
        for (final buttonConfig in toolbarConfig) {
          try {
            extensions.add(ToolbarButtonExtension.fromJson(
              buttonConfig as Map<String, dynamic>,
              plugin.id,
            ));
          } catch (e) {
            // 跳过无效配置
            continue;
          }
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的主题扩展
  List<PluginThemeExtension> getThemeExtensions() {
    final extensions = <PluginThemeExtension>[];
    
    for (final plugin in enabledPlugins) {
      final themeConfig = plugin.extensions['theme'];
      if (themeConfig != null && themeConfig is Map<String, dynamic>) {
        try {
          extensions.add(PluginThemeExtension.fromJson(themeConfig, plugin.id));
        } catch (e) {
          continue;
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的预览扩展
  List<PluginPreviewExtension> getPreviewExtensions() {
    final extensions = <PluginPreviewExtension>[];
    
    for (final plugin in enabledPlugins) {
      final previewConfig = plugin.extensions['preview'];
      if (previewConfig != null && previewConfig is Map<String, dynamic>) {
        try {
          extensions.add(PluginPreviewExtension.fromJson(previewConfig, plugin.id));
        } catch (e) {
          continue;
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的导航扩展
  List<PluginNavigationExtension> getNavigationExtensions() {
    final extensions = <PluginNavigationExtension>[];
    
    for (final plugin in enabledPlugins) {
      final navConfig = plugin.extensions['navigation'];
      if (navConfig != null && navConfig is List) {
        for (final itemConfig in navConfig) {
          try {
            extensions.add(PluginNavigationExtension.fromJson(
              itemConfig as Map<String, dynamic>,
              plugin.id,
            ));
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的文件操作扩展
  List<PluginFileActionExtension> getFileActionExtensions() {
    final extensions = <PluginFileActionExtension>[];
    
    for (final plugin in enabledPlugins) {
      final actionConfig = plugin.extensions['file_actions']; // 注意 key 可能不同，需确认 json 结构，假设是 file_actions
      if (actionConfig != null && actionConfig is List) {
        for (final itemConfig in actionConfig) {
          try {
            extensions.add(PluginFileActionExtension.fromJson(
              itemConfig as Map<String, dynamic>,
              plugin.id,
            ));
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的导出扩展
  List<PluginExportExtension> getExportExtensions() {
    final extensions = <PluginExportExtension>[];
    
    for (final plugin in enabledPlugins) {
      final exportConfig = plugin.extensions['export'];
      if (exportConfig != null && exportConfig is List) {
        for (final itemConfig in exportConfig) {
          try {
            extensions.add(PluginExportExtension.fromJson(
              itemConfig as Map<String, dynamic>,
              plugin.id,
            ));
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的编辑器扩展
  List<PluginEditorExtension> getEditorExtensions() {
    final extensions = <PluginEditorExtension>[];
    
    for (final plugin in enabledPlugins) {
      final editorConfig = plugin.extensions['editor'];
      if (editorConfig != null && editorConfig is Map<String, dynamic>) {
        try {
          extensions.add(PluginEditorExtension.fromJson(
            editorConfig,
            plugin.id,
          ));
        } catch (e) {
          continue;
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的小组件扩展
  List<PluginWidgetExtension> getWidgetExtensions() {
    final extensions = <PluginWidgetExtension>[];
    
    for (final plugin in enabledPlugins) {
      final widgetConfig = plugin.extensions['widget'];
      if (widgetConfig != null && widgetConfig is Map<String, dynamic>) {
        try {
          extensions.add(PluginWidgetExtension.fromJson(
            widgetConfig,
            plugin.id,
          ));
        } catch (e) {
          continue;
        }
      }
    }
    
    return extensions;
  }

  /// 获取所有已启用插件的快捷键扩展
  List<PluginShortcutExtension> getShortcutExtensions() {
    final extensions = <PluginShortcutExtension>[];
    
    for (final plugin in enabledPlugins) {
      final shortcutConfig = plugin.extensions['shortcuts'];
      if (shortcutConfig != null && shortcutConfig is List) {
        for (final itemConfig in shortcutConfig) {
          try {
            extensions.add(PluginShortcutExtension.fromJson(
              itemConfig as Map<String, dynamic>,
              plugin.id,
            ));
          } catch (e) {
            continue;
          }
        }
      }
    }
    
    return extensions;
  }
  
  /// 获取所有已启用插件的本地化扩展
  List<PluginLocalizationExtension> getLocalizationExtensions() {
    final extensions = <PluginLocalizationExtension>[];
    
    for (final plugin in enabledPlugins) {
      final locConfig = plugin.extensions['localization'];
      if (locConfig != null && locConfig is Map<String, dynamic>) {
        try {
          extensions.add(PluginLocalizationExtension.fromJson(
            locConfig,
            plugin.id,
          ));
        } catch (e) {
          continue;
        }
      }
    }
    
    return extensions;
  }

  /// 获取聚合后的自定义 CSS
  String getAggregatedCustomCss() {
    final buffer = StringBuffer();
    for (final ext in getPreviewExtensions()) {
      if (ext.customCss != null && ext.customCss!.isNotEmpty) {
        buffer.writeln('/* Plugin: ${ext.pluginId} */');
        buffer.writeln(ext.customCss);
      }
    }
    return buffer.toString();
  }
}

/// 插件安装结果
class PluginInstallResult {
  final bool success;
  final String message;
  final PluginManifest? manifest;

  PluginInstallResult({
    required this.success,
    required this.message,
    this.manifest,
  });
}
