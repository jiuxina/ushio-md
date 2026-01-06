// ============================================================================
// 应用设置状态管理器
// 
// 管理应用的所有设置选项，包括：
// - 主题模式（跟随系统/浅色/深色）
// - 主题色（8种预设颜色）
// - 编辑器设置（字体大小、自动保存）
// - 背景个性化（背景图片、模糊效果）
// 
// 所有设置使用 SharedPreferences 持久化存储。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 设置状态提供者
/// 
/// 管理应用的外观和行为设置
class SettingsProvider extends ChangeNotifier {
  // ==================== 安全存储 ====================
  
  /// 安全存储（用于敏感信息如密码）
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  
  // ==================== 主题设置 ====================
  
  /// 主题模式（system/light/dark）
  ThemeMode _themeMode = ThemeMode.system;
  
  /// 主题色索引（对应 themeColors 列表）
  int _primaryColorIndex = 0;
  
  /// 夜间主题索引（对应 AppConstants.darkThemeSchemes 列表）
  int _darkThemeIndex = 0;
  
  /// 浅色主题索引（对应 AppConstants.lightThemeSchemes 列表）
  int _lightThemeIndex = 0;
  
  /// UI 字体族（System 表示系统默认）
  String _uiFontFamily = 'System';
  
  /// 编辑器字体族
  String _editorFontFamily = 'System';
  
  /// 代码块字体族
  String _codeFontFamily = 'System';
  
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
  
  // ==================== 粒子效果设置 ====================
  
  /// 粒子效果开关
  bool _particleEnabled = false;
  
  /// 粒子效果类型：sakura/rain/firefly/snow
  String _particleType = 'sakura';
  
  /// 粒子速率（0.5-2.0）
  double _particleSpeed = 1.0;
  
  /// 是否全局显示（false 则仅在非编辑器区域显示）
  bool _particleGlobal = true;
  
  // ==================== 语言设置 ====================
  
  /// 当前语言环境（默认中文）
  Locale _locale = const Locale('zh', 'CN');

  // ==================== 云同步设置 ====================
  
  /// WebDAV 服务器地址
  String _webdavUrl = '';
  
  /// WebDAV 用户名
  String _webdavUsername = '';
  
  /// WebDAV 密码
  String _webdavPassword = '';
  
  /// 是否启用自动同步
  bool _autoSyncEnabled = false;
  
  /// 上次同步时间
  DateTime? _lastSyncTime;

  // ==================== 预设主题色 ====================
  
  /// 12种精选主题色
  static const List<Color> themeColors = [
    Color(0xFF6366F1),  // 靛蓝（默认）
    Color(0xFF3B82F6),  // 蓝色
    Color(0xFF10B981),  // 翠绿
    Color(0xFFF59E0B),  // 琥珀
    Color(0xFFEF4444),  // 红色
    Color(0xFF8B5CF6),  // 紫罗兰
    Color(0xFFEC4899),  // 粉色
    Color(0xFF14B8A6),  // 青色
    Color(0xFFF97316),  // 橙色
    Color(0xFF84CC16),  // 青柠
    Color(0xFF06B6D4),  // 天蓝
    Color(0xFFD946EF),  // 洋红
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
  
  // 粒子效果 Getters
  bool get particleEnabled => _particleEnabled;
  String get particleType => _particleType;
  double get particleSpeed => _particleSpeed;
  bool get particleGlobal => _particleGlobal;
  
  Locale get locale => _locale;
  int get darkThemeIndex => _darkThemeIndex;
  int get lightThemeIndex => _lightThemeIndex;
  String get uiFontFamily => _uiFontFamily;
  String get editorFontFamily => _editorFontFamily;
  String get codeFontFamily => _codeFontFamily;
  
  // 云同步 Getters
  String get webdavUrl => _webdavUrl;
  String get webdavUsername => _webdavUsername;
  String get webdavPassword => _webdavPassword;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isWebdavConfigured => _webdavUrl.isNotEmpty && _webdavUsername.isNotEmpty && _webdavPassword.isNotEmpty;

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
    
    // 粒子效果设置
    _particleEnabled = prefs.getBool('particle_enabled') ?? false;
    _particleType = prefs.getString('particle_type') ?? 'sakura';
    _particleSpeed = prefs.getDouble('particle_speed') ?? 1.0;
    _particleGlobal = prefs.getBool('particle_global') ?? true;
    
    // 语言设置
    final localeCode = prefs.getString('locale') ?? 'zh';
    _locale = localeCode == 'en' ? const Locale('en', 'US') : const Locale('zh', 'CN');
    
    // 夜间主题和字体设置
    _darkThemeIndex = prefs.getInt('dark_theme_index') ?? 0;
    _lightThemeIndex = prefs.getInt('light_theme_index') ?? 0;
    
    // 字体设置迁移逻辑
    final oldFontFamily = prefs.getString('font_family');
    _uiFontFamily = prefs.getString('font_family_ui') ?? oldFontFamily ?? 'System';
    _editorFontFamily = prefs.getString('font_family_editor') ?? oldFontFamily ?? 'System';
    _codeFontFamily = prefs.getString('font_family_code') ?? 'JetBrains Mono'; // 代码块默认使用 JetBrains Mono 如果有
    
    // 云同步设置
    _webdavUrl = prefs.getString('webdav_url') ?? '';
    _webdavUsername = prefs.getString('webdav_username') ?? '';
    _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
    final lastSyncMs = prefs.getInt('last_sync_time');
    _lastSyncTime = lastSyncMs != null ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs) : null;
    
    // 从安全存储读取密码（包含迁移逻辑）
    _webdavPassword = await _secureStorage.read(key: 'webdav_password') ?? '';
    
    // 迁移：如果安全存储中没有但 SharedPreferences 中有，则迁移
    if (_webdavPassword.isEmpty) {
      final oldPassword = prefs.getString('webdav_password');
      if (oldPassword != null && oldPassword.isNotEmpty) {
        _webdavPassword = oldPassword;
        await _secureStorage.write(key: 'webdav_password', value: oldPassword);
        await prefs.remove('webdav_password'); // 删除明文密码
      }
    }

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
  Future<void> setBackgroundEffect(String effect) async {
    _backgroundEffect = effect;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_effect', effect);
    notifyListeners();
  }

  /// 设置模糊强度
  Future<void> setBackgroundBlur(double blur) async {
    _backgroundBlur = blur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_blur', blur);
    notifyListeners();
  }

  /// 设置遮罩透明度
  Future<void> setBackgroundOverlayOpacity(double opacity) async {
    _backgroundOverlayOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_overlay_opacity', opacity);
    notifyListeners();
  }

  // ==================== 粒子效果设置方法 ====================

  /// 设置粒子效果开关
  Future<void> setParticleEnabled(bool enabled) async {
    _particleEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('particle_enabled', enabled);
    notifyListeners();
  }

  /// 设置粒子效果类型
  Future<void> setParticleType(String type) async {
    _particleType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('particle_type', type);
    notifyListeners();
  }

  /// 设置粒子速率
  Future<void> setParticleSpeed(double speed) async {
    _particleSpeed = speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('particle_speed', speed);
    notifyListeners();
  }

  /// 设置粒子全局显示
  Future<void> setParticleGlobal(bool global) async {
    _particleGlobal = global;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('particle_global', global);
    notifyListeners();
  }

  // ==================== 编辑器设置方法 ====================

  /// 设置编辑器字体大小
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
  Future<void> setAutoSaveInterval(int seconds) async {
    _autoSaveInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_save_interval', seconds);
    notifyListeners();
  }

  /// 设置默认目录
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

  // ==================== 语言设置方法 ====================

  /// 设置应用语言
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }

  // ==================== 夜间主题和字体设置方法 ====================

  /// 设置夜间主题索引
  Future<void> setDarkThemeIndex(int index) async {
    _darkThemeIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dark_theme_index', index);
    notifyListeners();
  }

  /// 设置浅色主题索引
  Future<void> setLightThemeIndex(int index) async {
    _lightThemeIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('light_theme_index', index);
    notifyListeners();
  }

  /// 设置 UI 字体
  Future<void> setUiFontFamily(String fontFamily) async {
    _uiFontFamily = fontFamily;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family_ui', fontFamily);
    notifyListeners();
  }
  
  /// 设置编辑器字体
  Future<void> setEditorFontFamily(String fontFamily) async {
    _editorFontFamily = fontFamily;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family_editor', fontFamily);
    notifyListeners();
  }

  /// 设置代码块字体
  Future<void> setCodeFontFamily(String fontFamily) async {
    _codeFontFamily = fontFamily;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family_code', fontFamily);
    notifyListeners();
  }

  // ==================== 云同步设置方法 ====================

  /// 设置 WebDAV 服务器地址
  Future<void> setWebdavUrl(String url) async {
    _webdavUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    notifyListeners();
  }

  /// 设置 WebDAV 用户名
  Future<void> setWebdavUsername(String username) async {
    _webdavUsername = username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_username', username);
    notifyListeners();
  }

  /// 设置 WebDAV 密码（安全存储）
  Future<void> setWebdavPassword(String password) async {
    _webdavPassword = password;
    await _secureStorage.write(key: 'webdav_password', value: password);
    notifyListeners();
  }

  /// 设置自动同步开关
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', enabled);
    notifyListeners();
  }

  /// 更新上次同步时间
  Future<void> updateLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);
    notifyListeners();
  }

  /// 保存所有 WebDAV 凭据
  /// 
  /// 密码使用安全存储，URL 和用户名使用 SharedPreferences
  Future<void> saveWebdavCredentials({
    required String url,
    required String username,
    required String password,
  }) async {
    _webdavUrl = url;
    _webdavUsername = username;
    _webdavPassword = password;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_username', username);
    // 密码使用安全存储
    await _secureStorage.write(key: 'webdav_password', value: password);
    notifyListeners();
  }
}
