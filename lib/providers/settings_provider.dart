/// ============================================================================
/// 应用设置状态管理器
/// ============================================================================
/// 
/// 管理应用的所有设置选项，包括：
/// - 主题模式（跟随系统/浅色/深色）
/// - 主题色（8种预设颜色）
/// - 编辑器设置（字体大小、自动保存）
/// - 背景个性化（背景图片、模糊效果）
/// 
/// 所有设置使用 SharedPreferences 持久化存储。
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置状态提供者
/// 
/// 管理应用的外观和行为设置
class SettingsProvider extends ChangeNotifier {
  // ==================== 主题设置 ====================
  
  /// 主题模式（system/light/dark）
  ThemeMode _themeMode = ThemeMode.system;
  
  /// 主题色索引（对应 themeColors 列表）
  int _primaryColorIndex = 0;
  
  // ==================== 编辑器设置 ====================
  
  /// 编辑器字体大小（12-24px）
  double _fontSize = 16.0;
  
  /// 是否启用自动保存
  bool _autoSave = true;
  
  /// 自动保存间隔（秒）
  int _autoSaveInterval = 30;
  
  /// 默认目录路径
  String? _defaultDirectory;
  
  // ==================== 背景设置 ====================
  
  /// 背景图片路径（null 表示无背景图）
  String? _backgroundImagePath;
  
  /// 背景效果类型：none（无）、blur（模糊）
  String _backgroundEffect = 'none';
  
  /// 模糊效果强度（0-30）
  double _backgroundBlur = 10.0;
  
  /// 遮罩透明度（0-1，保留但当前 UI 未使用）
  double _backgroundOverlayOpacity = 0.5;

  // ==================== 预设主题色 ====================
  
  /// 8种精选主题色
  static const List<Color> themeColors = [
    Color(0xFF6366F1),  // 靛蓝（默认）
    Color(0xFF3B82F6),  // 蓝色
    Color(0xFF10B981),  // 翠绿
    Color(0xFFF59E0B),  // 琥珀
    Color(0xFFEF4444),  // 红色
    Color(0xFF8B5CF6),  // 紫罗兰
    Color(0xFFEC4899),  // 粉色
    Color(0xFF14B8A6),  // 青色
  ];

  // ==================== Getters ====================
  
  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  bool get autoSave => _autoSave;
  int get autoSaveInterval => _autoSaveInterval;
  String? get defaultDirectory => _defaultDirectory;
  int get primaryColorIndex => _primaryColorIndex;
  Color get primaryColor => themeColors[_primaryColorIndex];
  String? get backgroundImagePath => _backgroundImagePath;
  String get backgroundEffect => _backgroundEffect;
  double get backgroundBlur => _backgroundBlur;
  double get backgroundOverlayOpacity => _backgroundOverlayOpacity;

  // ==================== 初始化 ====================

  /// 从本地存储加载所有设置
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 主题设置
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];
    _primaryColorIndex = prefs.getInt('primary_color_index') ?? 0;
    
    // 编辑器设置
    _fontSize = prefs.getDouble('font_size') ?? 16.0;
    _autoSave = prefs.getBool('auto_save') ?? true;
    _autoSaveInterval = prefs.getInt('auto_save_interval') ?? 30;
    _defaultDirectory = prefs.getString('default_directory');
    
    // 背景设置
    _backgroundImagePath = prefs.getString('background_image_path');
    _backgroundEffect = prefs.getString('background_effect') ?? 'none';
    _backgroundBlur = prefs.getDouble('background_blur') ?? 10.0;
    _backgroundOverlayOpacity = prefs.getDouble('background_overlay_opacity') ?? 0.5;

    notifyListeners();
  }

  // ==================== 主题设置方法 ====================

  /// 设置主题模式
  /// 
  /// [mode] ThemeMode.system / ThemeMode.light / ThemeMode.dark
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  /// 设置主题色
  /// 
  /// [index] 颜色在 themeColors 中的索引（0-7）
  Future<void> setPrimaryColorIndex(int index) async {
    _primaryColorIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color_index', index);
    notifyListeners();
  }

  // ==================== 背景设置方法 ====================

  /// 设置背景图片
  /// 
  /// [path] 图片的绝对路径，null 表示清除背景图
  Future<void> setBackgroundImage(String? path) async {
    _backgroundImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('background_image_path', path);
    } else {
      await prefs.remove('background_image_path');
    }
    notifyListeners();
  }

  /// 设置背景效果
  /// 
  /// [effect] 'none'（无效果）或 'blur'（模糊效果）
  Future<void> setBackgroundEffect(String effect) async {
    _backgroundEffect = effect;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_effect', effect);
    notifyListeners();
  }

  /// 设置模糊强度
  /// 
  /// [blur] 模糊半径（0-30）
  Future<void> setBackgroundBlur(double blur) async {
    _backgroundBlur = blur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_blur', blur);
    notifyListeners();
  }

  /// 设置遮罩透明度（保留方法，当前 UI 未使用）
  Future<void> setBackgroundOverlayOpacity(double opacity) async {
    _backgroundOverlayOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_overlay_opacity', opacity);
    notifyListeners();
  }

  // ==================== 编辑器设置方法 ====================

  /// 设置编辑器字体大小
  /// 
  /// [size] 字体大小（推荐 12-24px）
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
    notifyListeners();
  }

  /// 设置是否启用自动保存
  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_save', value);
    notifyListeners();
  }

  /// 设置自动保存间隔
  /// 
  /// [seconds] 保存间隔（秒）
  Future<void> setAutoSaveInterval(int seconds) async {
    _autoSaveInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_save_interval', seconds);
    notifyListeners();
  }

  /// 设置默认目录
  /// 
  /// [path] 目录的绝对路径，null 表示清除
  Future<void> setDefaultDirectory(String? path) async {
    _defaultDirectory = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('default_directory', path);
    } else {
      await prefs.remove('default_directory');
    }
    notifyListeners();
  }
}
