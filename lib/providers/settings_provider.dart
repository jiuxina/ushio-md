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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_style.dart';
import '../utils/platform_adapter.dart';

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

  /// 按钮风格（经典描边 / 简洁立体）
  AppButtonStyleMode _buttonStyleMode = AppButtonStyleMode.softShadow;

  /// 编辑器字体族
  String _editorFontFamily = 'System';

  /// 代码块字体族
  String _codeFontFamily = 'System';

  // ==================== 编辑器设置 ====================

  /// 编辑器字体大小（12-24px）
  double _fontSize = 16.0;

  /// 是否启用自动保存
  bool _autoSave = false;

  /// 自动保存间隔（秒）
  int _autoSaveInterval = 30;

  /// 调试模式开关
  bool _debugEnabled = false;

  /// 调试日志（内存环形缓冲）
  final List<String> _debugLogs = <String>[];

  /// 默认目录路径
  String? _defaultDirectory;

  /// 工作区文件夹名称
  String _workspaceName = 'Ushio-md';

  /// 自定义工作区基础路径（可选，为null时使用平台默认路径）
  String? _customWorkspaceBasePath;

  // ==================== 背景设置 ====================

  /// 背景图片路径（null 表示无背景图）
  String? _backgroundImagePath;

  /// 编辑器背景图片路径（null 表示无背景图）
  String? _editorBackgroundImagePath;

  /// 背景效果类型：none（无）、blur（模糊）
  String _backgroundEffect = 'none';

  /// 模糊效果强度（0-30）
  double _backgroundBlur = 10.0;

  /// 主背景亮度（0.2-1.8，1.0 为原始亮度）
  double _backgroundBrightness = 1.0;

  /// 编辑器背景是否启用模糊
  bool _editorBackgroundBlurEnabled = false;

  /// 编辑器背景模糊强度（0-30）
  double _editorBackgroundBlur = 10.0;

  /// 编辑器背景亮度（0.2-1.8，1.0 为原始亮度）
  double _editorBackgroundBrightness = 1.0;

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

  // ==================== 更新设置 ====================

  /// 是否在启动时自动检查更新（默认开启）
  bool _autoCheckUpdate = true;

  // ==================== 底栏设置 ====================

  /// 卡片透明度（0.4–1.0）
  double _cardOpacity = 1.0;

  /// 底部导航栏透明度（0.1–1.0）
  double _tabBarOpacity = 0.95;

  // ==================== 图标设置 ====================

  /// 桌面图标索引（0=默认 app.png, 1=icon2.png）
  int _appIconIndex = 0;

  /// 主页左上角图标模式：default / icon2 / custom / none
  String _homeIconMode = 'default';

  /// 主页自定义图标路径（仅当 homeIconMode == 'custom' 时有效）
  String? _homeIconCustomPath;

  /// 主页左上角标题文字
  String _homeTitleText = '汐';

  // ==================== 语言设置 ====================

  /// 当前语言环境（默认中文）
  Locale _locale = const Locale('zh');

  // ==================== 云同步设置 ====================

  /// 同步类型（webdav 或 ftp）
  String _syncType = 'webdav';

  /// WebDAV 服务器地址
  String _webdavUrl = '';

  /// WebDAV 用户名
  String _webdavUsername = '';

  /// WebDAV 密码
  String _webdavPassword = '';

  /// FTP 服务器 URL (格式: ftp://host:port)
  String _ftpUrl = '';

  /// FTP 用户名
  String _ftpUsername = '';

  /// FTP 密码
  String _ftpPassword = '';

  /// 云端同步文件夹名称
  String _syncFolderName = 'Ushio-MD';

  /// 云端文件夹路径前缀（不含文件夹名称）
  String _syncRemotePath = '/storage/emulated/0/';

  /// 是否启用自动同步
  bool _autoSyncEnabled = false;

  /// 上次同步时间
  DateTime? _lastSyncTime;

  // ==================== 预设主题色 ====================

  /// 12种精选主题色
  static const List<Color> themeColors = [
    Color(0xFF6366F1), // 靛蓝（默认）
    Color(0xFF3B82F6), // 蓝色
    Color(0xFF10B981), // 翠绿
    Color(0xFFF59E0B), // 琥珀
    Color(0xFFEF4444), // 红色
    Color(0xFF8B5CF6), // 紫罗兰
    Color(0xFFEC4899), // 粉色
    Color(0xFF14B8A6), // 青色
    Color(0xFFF97316), // 橙色
    Color(0xFF84CC16), // 青柠
    Color(0xFF06B6D4), // 天蓝
    Color(0xFFD946EF), // 洋红
  ];

  // ==================== Getters ====================

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  bool get autoSave => _autoSave;
  int get autoSaveInterval => _autoSaveInterval;
  bool get debugEnabled => _debugEnabled;
  List<String> get debugLogs => List.unmodifiable(_debugLogs);
  String? get defaultDirectory => _defaultDirectory;
  String get workspaceName => _workspaceName;
  String? get customWorkspaceBasePath => _customWorkspaceBasePath;
  int get primaryColorIndex => _primaryColorIndex;
  Color get primaryColor => themeColors[_primaryColorIndex];
  String? get backgroundImagePath => _backgroundImagePath;
  String? get editorBackgroundImagePath => _editorBackgroundImagePath;
  String get backgroundEffect => _backgroundEffect;
  double get backgroundBlur => _backgroundBlur;
  double get backgroundBrightness => _backgroundBrightness;
  bool get editorBackgroundBlurEnabled => _editorBackgroundBlurEnabled;
  double get editorBackgroundBlur => _editorBackgroundBlur;
  double get editorBackgroundBrightness => _editorBackgroundBrightness;
  double get backgroundOverlayOpacity => _backgroundOverlayOpacity;

  bool get autoCheckUpdate => _autoCheckUpdate;
  double get cardOpacity => _cardOpacity;
  double get tabBarOpacity => _tabBarOpacity;

  // 图标设置 Getters
  int get appIconIndex => _appIconIndex;
  String get homeIconMode => _homeIconMode;
  String? get homeIconCustomPath => _homeIconCustomPath;
  String get homeTitleText => _homeTitleText;

  // 粒子效果 Getters
  bool get particleEnabled => _particleEnabled;
  String get particleType => _particleType;
  double get particleSpeed => _particleSpeed;
  bool get particleGlobal => _particleGlobal;

  Locale get locale => _locale;
  int get darkThemeIndex => _darkThemeIndex;
  int get lightThemeIndex => _lightThemeIndex;
  String get uiFontFamily => _uiFontFamily;
  AppButtonStyleMode get buttonStyleMode => _buttonStyleMode;
  bool get useBorderlessButtons =>
      _buttonStyleMode == AppButtonStyleMode.softShadow;
  String get editorFontFamily => _editorFontFamily;
  String get codeFontFamily => _codeFontFamily;

  // 云同步 Getters
  String get syncType => _syncType;
  String get webdavUrl => _webdavUrl;
  String get webdavUsername => _webdavUsername;
  // 密码不通过公共 getter 暴露，仅在内部使用
  // String get webdavPassword => _webdavPassword;  // 已移除：安全性改进
  String get ftpUrl => _ftpUrl;

  /// 从 FTP URL 解析主机名
  String get ftpHost {
    try {
      final url = _ftpUrl.trim();
      if (url.isEmpty) return '';

      // 移除 ftp:// 前缀和末尾斜杠
      String cleanUrl = url;
      if (cleanUrl.startsWith('ftp://')) {
        cleanUrl = cleanUrl.substring(6);
      }
      cleanUrl = cleanUrl.replaceAll(RegExp(r'/+$'), '');

      // 分离主机和端口
      if (cleanUrl.contains(':')) {
        return cleanUrl.split(':')[0];
      }
      return cleanUrl;
    } catch (e) {
      return '';
    }
  }

  /// 从 FTP URL 解析端口
  int get ftpPort {
    try {
      final url = _ftpUrl.trim();
      if (url.isEmpty) return 21;

      // 移除 ftp:// 前缀和末尾斜杠
      String cleanUrl = url;
      if (cleanUrl.startsWith('ftp://')) {
        cleanUrl = cleanUrl.substring(6);
      }
      cleanUrl = cleanUrl.replaceAll(RegExp(r'/+$'), '');

      // 提取端口
      if (cleanUrl.contains(':')) {
        final parts = cleanUrl.split(':');
        if (parts.length >= 2) {
          return int.tryParse(parts[1]) ?? 21;
        }
      }
      return 21;
    } catch (e) {
      return 21;
    }
  }

  String get ftpUsername => _ftpUsername;
  // 密码不通过公共 getter 暴露，仅在内部使用
  // String get ftpPassword => _ftpPassword;  // 已移除：安全性改进
  String get syncFolderName => _syncFolderName;
  String get syncRemotePath => _syncRemotePath;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool get isWebdavConfigured =>
      _webdavUrl.isNotEmpty &&
      _webdavUsername.isNotEmpty &&
      _webdavPassword.isNotEmpty;
  bool get isFtpConfigured =>
      _ftpUrl.isNotEmpty && _ftpUsername.isNotEmpty && _ftpPassword.isNotEmpty;
  bool get isSyncConfigured =>
      _syncType == 'webdav' ? isWebdavConfigured : isFtpConfigured;

  /// 安全地获取 WebDAV 凭据（仅用于创建服务实例）
  /// 不要在 UI 层调用此方法
  Map<String, String> getWebdavCredentials() {
    return {
      'url': _webdavUrl,
      'username': _webdavUsername,
      'password': _webdavPassword,
    };
  }

  /// 安全地获取 FTP 凭据（仅用于创建服务实例）
  /// 不要在 UI 层调用此方法
  Map<String, String> getFtpCredentials() {
    return {'url': _ftpUrl, 'username': _ftpUsername, 'password': _ftpPassword};
  }

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
    _autoSave = prefs.getBool('auto_save') ?? false;
    _autoSaveInterval = prefs.getInt('auto_save_interval') ?? 30;
    _debugEnabled = prefs.getBool('debug_enabled') ?? false;
    _defaultDirectory = prefs.getString('default_directory');
    _workspaceName = prefs.getString('workspace_name') ?? 'Ushio-md';

    // 自定义工作区基础路径 - 如果未设置，使用平台默认路径
    final savedCustomPath = prefs.getString('custom_workspace_base_path');
    if (savedCustomPath != null && savedCustomPath.isNotEmpty) {
      _customWorkspaceBasePath = savedCustomPath;
    } else {
      // 使用平台默认路径
      _customWorkspaceBasePath =
          await PlatformAdapter.getDefaultWorkspaceBasePath();
    }

    // 背景设置
    _backgroundImagePath = prefs.getString('background_image_path');
    _editorBackgroundImagePath = prefs.getString(
      'editor_background_image_path',
    );
    _backgroundEffect = prefs.getString('background_effect') ?? 'none';
    _backgroundBlur = prefs.getDouble('background_blur') ?? 10.0;
    _backgroundBrightness = prefs.getDouble('background_brightness') ?? 1.0;
    _editorBackgroundBlurEnabled =
        prefs.getBool('editor_background_blur_enabled') ?? false;
    _editorBackgroundBlur = prefs.getDouble('editor_background_blur') ?? 10.0;
    _editorBackgroundBrightness =
        prefs.getDouble('editor_background_brightness') ?? 1.0;
    _backgroundOverlayOpacity =
        prefs.getDouble('background_overlay_opacity') ?? 0.5;

    // 粒子效果设置
    _particleEnabled = prefs.getBool('particle_enabled') ?? false;
    _particleType = prefs.getString('particle_type') ?? 'sakura';
    _particleSpeed = prefs.getDouble('particle_speed') ?? 1.0;
    _particleGlobal = prefs.getBool('particle_global') ?? true;

    // 语言设置
    // 如果用户没有设置过语言，则使用系统语言
    final savedLocaleCode = prefs.getString('locale');
    if (savedLocaleCode != null && savedLocaleCode.isNotEmpty) {
      // 用户已设置过语言，使用保存的语言（只保存语言代码，不带国家代码）
      _locale = Locale(savedLocaleCode);
    } else {
      // 首次启动，根据系统语言自动设置
      // 默认使用中文，只有系统语言明确为英语时才使用英语
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (systemLocale.languageCode == 'en') {
        _locale = const Locale('en');
      } else {
        _locale = const Locale('zh');
      }
    }

    // 更新设置
    _autoCheckUpdate = prefs.getBool('auto_check_update') ?? true;

    // 底栏设置
    _cardOpacity = prefs.getDouble('card_opacity') ?? 1.0;
    _tabBarOpacity = prefs.getDouble('tab_bar_opacity') ?? 0.95;

    // 图标设置
    _appIconIndex = prefs.getInt('app_icon_index') ?? 0;
    _homeIconMode = prefs.getString('home_icon_mode') ?? 'default';
    _homeIconCustomPath = prefs.getString('home_icon_custom_path');
    _homeTitleText = prefs.getString('home_title_text') ?? '汐';

    // 夜间主题和字体设置
    _darkThemeIndex = prefs.getInt('dark_theme_index') ?? 0;
    _lightThemeIndex = prefs.getInt('light_theme_index') ?? 0;

    final buttonStyleName = prefs.getString('button_style_mode');
    _buttonStyleMode = AppButtonStyleMode.values.firstWhere(
      (mode) => mode.name == buttonStyleName,
      orElse: () => AppButtonStyleMode.softShadow,
    );

    // 字体设置迁移逻辑
    final oldFontFamily = prefs.getString('font_family');
    _uiFontFamily =
        prefs.getString('font_family_ui') ?? oldFontFamily ?? 'System';
    _editorFontFamily =
        prefs.getString('font_family_editor') ?? oldFontFamily ?? 'System';
    _codeFontFamily =
        prefs.getString('font_family_code') ??
        'JetBrains Mono'; // 代码块默认使用 JetBrains Mono 如果有

    // 云同步设置
    _syncType = prefs.getString('sync_type') ?? 'webdav';
    _webdavUrl = prefs.getString('webdav_url') ?? '';
    _webdavUsername = prefs.getString('webdav_username') ?? '';

    // FTP URL 设置（包含从旧格式的迁移逻辑）
    _ftpUrl = prefs.getString('ftp_url') ?? '';
    if (_ftpUrl.isEmpty) {
      // 迁移旧格式：从 ftp_host 和 ftp_port 生成 URL
      final oldHost = prefs.getString('ftp_host') ?? '';
      final oldPort = prefs.getInt('ftp_port') ?? 21;
      if (oldHost.isNotEmpty) {
        _ftpUrl = 'ftp://$oldHost:$oldPort';
        // 保存新格式
        await prefs.setString('ftp_url', _ftpUrl);
        // 清理旧数据
        await prefs.remove('ftp_host');
        await prefs.remove('ftp_port');
      }
    }

    _ftpUsername = prefs.getString('ftp_username') ?? '';
    _syncFolderName = prefs.getString('sync_folder_name') ?? 'Ushio-MD';
    _syncRemotePath =
        prefs.getString('sync_remote_path') ?? '/storage/emulated/0/';
    _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
    final lastSyncMs = prefs.getInt('last_sync_time');
    _lastSyncTime = lastSyncMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
        : null;

    // 从安全存储读取密码（包含迁移逻辑）
    _webdavPassword = await _secureStorage.read(key: 'webdav_password') ?? '';
    _ftpPassword = await _secureStorage.read(key: 'ftp_password') ?? '';

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
  ///
  /// 将图片复制到应用私有目录，避免清理缓存后图片丢失
  Future<void> setBackgroundImage(String? path) async {
    if (path == null) {
      // 清除背景图片
      // 删除旧的背景图片文件
      if (_backgroundImagePath != null) {
        try {
          final oldFile = File(_backgroundImagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (e) { debugPrint('操作失败: $e'); }
      }
      _backgroundImagePath = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_image_path');
      notifyListeners();
      return;
    }

    try {
      // 将图片复制到应用私有目录
      final appDir = await getApplicationSupportDirectory();
      final bgDir = Directory('${appDir.path}/backgrounds');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final sourceFile = File(path);
      final fileName =
          'background_${DateTime.now().millisecondsSinceEpoch}.${path.split('.').last}';
      final destPath = '${bgDir.path}/$fileName';

      // 复制文件
      await sourceFile.copy(destPath);

      // 删除旧的背景图片文件（如果有）
      if (_backgroundImagePath != null && _backgroundImagePath != destPath) {
        try {
          final oldFile = File(_backgroundImagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (e) { debugPrint('操作失败: $e'); }
      }

      _backgroundImagePath = destPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_image_path', destPath);
      notifyListeners();
    } catch (e) {
      // 如果复制失败，直接使用原路径（回退方案）
      _backgroundImagePath = path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_image_path', path);
      notifyListeners();
    }
  }

  /// 设置编辑器背景图片
  ///
  /// 将图片复制到应用私有目录，避免清理缓存后图片丢失
  Future<void> setEditorBackgroundImage(String? path) async {
    if (path == null) {
      // 清除编辑器背景图片
      if (_editorBackgroundImagePath != null) {
        try {
          final oldFile = File(_editorBackgroundImagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (e) { debugPrint('操作失败: $e'); }
      }
      _editorBackgroundImagePath = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('editor_background_image_path');
      notifyListeners();
      return;
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final bgDir = Directory('${appDir.path}/editor_backgrounds');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final sourceFile = File(path);
      final fileName =
          'editor_background_${DateTime.now().millisecondsSinceEpoch}.${path.split('.').last}';
      final destPath = '${bgDir.path}/$fileName';

      await sourceFile.copy(destPath);

      if (_editorBackgroundImagePath != null &&
          _editorBackgroundImagePath != destPath) {
        try {
          final oldFile = File(_editorBackgroundImagePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (e) { debugPrint('操作失败: $e'); }
      }

      _editorBackgroundImagePath = destPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('editor_background_image_path', destPath);
      notifyListeners();
    } catch (e) {
      // 如果复制失败，直接使用原路径（回退方案）
      _editorBackgroundImagePath = path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('editor_background_image_path', path);
      notifyListeners();
    }
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

  /// 仅在内存中更新背景亮度（不持久化），用于 Slider 拖动时实时预览
  void updateBackgroundBrightnessInMemory(double brightness) {
    _backgroundBrightness = brightness;
    notifyListeners();
  }

  /// 设置背景亮度（立即刷新 UI，再异步持久化）
  Future<void> setBackgroundBrightness(double brightness) async {
    _backgroundBrightness = brightness;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_brightness', brightness);
  }

  /// 设置编辑器背景模糊开关
  Future<void> setEditorBackgroundBlurEnabled(bool enabled) async {
    _editorBackgroundBlurEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('editor_background_blur_enabled', enabled);
    notifyListeners();
  }

  /// 设置编辑器背景模糊强度
  Future<void> setEditorBackgroundBlur(double blur) async {
    _editorBackgroundBlur = blur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('editor_background_blur', blur);
    notifyListeners();
  }

  /// 仅在内存中更新编辑器背景亮度（不持久化），用于 Slider 拖动时实时预览
  void updateEditorBackgroundBrightnessInMemory(double brightness) {
    _editorBackgroundBrightness = brightness;
    notifyListeners();
  }

  /// 设置编辑器背景亮度（立即刷新 UI，再异步持久化）
  Future<void> setEditorBackgroundBrightness(double brightness) async {
    _editorBackgroundBrightness = brightness;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('editor_background_brightness', brightness);
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

  /// 设置调试开关
  Future<void> setDebugEnabled(bool value) async {
    _debugEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_enabled', value);
    notifyListeners();
  }

  /// 追加调试日志（内存最多保留 300 条）
  void appendDebugLog(String message) {
    final ts = DateTime.now().toIso8601String();
    _debugLogs.add('[$ts] $message');
    const maxLogs = 300;
    if (_debugLogs.length > maxLogs) {
      _debugLogs.removeRange(0, _debugLogs.length - maxLogs);
    }
    notifyListeners();
  }

  /// 清空调试日志
  void clearDebugLogs() {
    _debugLogs.clear();
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

  /// 设置工作区文件夹名称
  Future<void> setWorkspaceName(String name) async {
    _workspaceName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workspace_name', name);
    notifyListeners();
  }

  /// 设置自定义工作区基础路径
  Future<void> setCustomWorkspaceBasePath(String? path) async {
    _customWorkspaceBasePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString('custom_workspace_base_path', path);
    } else {
      await prefs.remove('custom_workspace_base_path');
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

  // ==================== 更新设置方法 ====================

  /// 设置启动时是否自动检查更新
  Future<void> setAutoCheckUpdate(bool value) async {
    _autoCheckUpdate = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_check_update', value);
    notifyListeners();
  }

  /// 设置卡片透明度
  Future<void> setCardOpacity(double opacity) async {
    _cardOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('card_opacity', opacity);
    notifyListeners();
  }

  /// 设置底部导航栏透明度
  Future<void> setTabBarOpacity(double opacity) async {
    _tabBarOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tab_bar_opacity', opacity);
    notifyListeners();
  }

  // ==================== 图标设置方法 ====================

  /// 设置桌面图标索引（0=默认, 1=icon2）
  Future<void> setAppIconIndex(int index) async {
    _appIconIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_icon_index', index);
    notifyListeners();
  }

  /// 设置主页图标模式
  Future<void> setHomeIconMode(String mode) async {
    _homeIconMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_icon_mode', mode);
    notifyListeners();
  }

  /// 设置主页自定义图标路径
  Future<void> setHomeIconCustomPath(String? path) async {
    _homeIconCustomPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('home_icon_custom_path', path);
    } else {
      await prefs.remove('home_icon_custom_path');
    }
    notifyListeners();
  }

  /// 设置主页标题文字
  Future<void> setHomeTitleText(String text) async {
    final normalized = text.trim().isEmpty ? '汐' : text.trim();
    _homeTitleText = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_title_text', normalized);
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

  /// 设置按钮风格
  Future<void> setButtonStyleMode(AppButtonStyleMode mode) async {
    _buttonStyleMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('button_style_mode', mode.name);
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

  /// 设置同步类型
  Future<void> setSyncType(String type) async {
    _syncType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_type', type);
    notifyListeners();
  }

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

  /// 设置 FTP 服务器 URL
  Future<void> setFtpUrl(String url) async {
    // 规范化 URL：移除末尾的斜杠
    String cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');

    _ftpUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ftp_url', cleanUrl);
    notifyListeners();
  }

  /// 设置 FTP 用户名
  Future<void> setFtpUsername(String username) async {
    _ftpUsername = username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ftp_username', username);
    notifyListeners();
  }

  /// 设置 FTP 密码（安全存储）
  Future<void> setFtpPassword(String password) async {
    _ftpPassword = password;
    await _secureStorage.write(key: 'ftp_password', value: password);
    notifyListeners();
  }

  /// 设置云端同步文件夹名称
  Future<void> setSyncFolderName(String folderName) async {
    _syncFolderName = folderName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_folder_name', folderName);
    notifyListeners();
  }

  /// 设置云端文件夹路径前缀
  Future<void> setSyncRemotePath(String path) async {
    _syncRemotePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_remote_path', path);
    notifyListeners();
  }

  /// 获取完整的云端文件夹路径（路径前缀 + 文件夹名称）
  String getFullSyncPath() {
    String fullPath = _syncRemotePath.trim();

    // 如果没有路径前缀，直接返回文件夹名称
    if (fullPath.isEmpty) {
      return _syncFolderName;
    }

    // 确保路径以 / 结尾
    if (!fullPath.endsWith('/')) {
      fullPath += '/';
    }

    // 自动补齐文件夹名称（如果路径不以文件夹名称结尾）
    if (!fullPath.endsWith('$_syncFolderName/') &&
        !fullPath.endsWith(_syncFolderName)) {
      fullPath += _syncFolderName;
    }

    return fullPath;
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
