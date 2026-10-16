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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_style.dart';
import '../utils/platform_adapter.dart';
import '../utils/debug_log.dart';
import '../utils/theme_tones.dart';
import 'dart:convert';

/// 设置状态提供者
///
/// 管理应用的外观和行为设置
class SettingsProvider extends ChangeNotifier {
  // ==================== 持久化缓存 ====================

  /// 缓存的 SharedPreferences 实例，避免每次 setter 都 getInstance()
  SharedPreferences? _prefsCache;

  /// 防抖持久化 Timer，用于 Slider 等高频更新场景
  Timer? _persistDebounce;

  /// 待持久化的键值对
  final Map<String, dynamic> _pendingPersist = {};

  Future<SharedPreferences> _getPrefs() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  /// 防抖持久化：500ms 内多次调用只执行一次写入
  void _schedulePersist(String key, dynamic value) {
    _pendingPersist[key] = value;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), () async {
      final entries = Map<String, dynamic>.from(_pendingPersist);
      _pendingPersist.clear();
      final prefs = await _getPrefs();
      for (final entry in entries.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v is double)
          await prefs.setDouble(k, v);
        else if (v is int)
          await prefs.setInt(k, v);
        else if (v is bool)
          await prefs.setBool(k, v);
        else if (v is String)
          await prefs.setString(k, v);
      }
    });
  }

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

  /// 自定义主题色；非空即表示用户覆盖了预设
  Color? _customThemeColor;

  /// 界面字体颜色索引（对应 uiFontColors 列表）
  int _uiFontColorIndex = 0;

  /// 自定义界面字体颜色；非空即表示用户覆盖了预设
  Color? _customUiFontColor;

  /// 编辑器文字颜色索引（对应 editorFontColors 列表）
  int _editorFontColorIndex = 0;

  /// 自定义编辑器文字颜色；非空即表示用户覆盖了预设
  Color? _customEditorFontColor;

  /// 夜间主题索引（对应 AppConstants.darkThemeSchemes 列表）
  int _darkThemeIndex = 0;

  /// 浅色主题索引（对应 AppConstants.lightThemeSchemes 列表）
  int _lightThemeIndex = 0;

  /// UI 字体族（System 表示系统默认）
  String _uiFontFamily = 'System';

  /// 按钮风格（经典描边 / 简洁立体）
  AppButtonStyleMode _buttonStyleMode = AppButtonStyleMode.liquidGlass;

  /// 编辑器字体族
  String _editorFontFamily = 'System';

  /// 代码块字体族
  String _codeFontFamily = 'System';

  /// 代码块主题索引（对应 AppConstants.codeBlockThemes 列表）
  int _codeBlockThemeIndex = 0;

  // ==================== 编辑器设置 ====================

  /// 编辑器字体大小（6-80px）
  double _fontSize = 16.0;

  /// 是否启用自动保存
  bool _autoSave = false;

  /// 自动保存间隔（秒）
  int _autoSaveInterval = 30;

  /// 退出文档时自动保存
  bool _saveOnExit = false;

  /// 行高（1.0-2.5）
  double _lineHeight = 1.6;

  /// 字间距（-2.0 到 10.0，单位 px）
  double _letterSpacing = 0.0;

  /// 段落间距（0-40px）
  double _paragraphSpacing = 8.0;

  /// 启动行为：blank（空白页）/ restore（恢复上次文件）
  String _startupBehavior = 'blank';

  /// 上次打开的文件路径
  String? _lastOpenedFilePath;

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

  /// 编辑器背景图片是否存在（在设置路径时异步验证，避免 build 中 existsSync）
  bool _editorBackgroundImageExists = false;

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

  // ==================== 更新设置 ====================

  /// 是否在启动时自动检查更新（默认开启）
  bool _autoCheckUpdate = true;

  /// 更新规则：stable=稳定版，prerelease=测试版
  String _updateChannel = 'stable';

  /// 用户自定义下载代理前缀列表，按顺序尝试；为空则直连
  List<String> _updateProxies = [];

  // ==================== 底栏设置 ====================

  /// 卡片透明度（0.4–1.0）
  double _cardOpacity = 1.0;

  /// 底部导航栏透明度（0.1–1.0）
  double _tabBarOpacity = 0.95;

  /// 自定义卡片颜色；非空即表示用户覆盖了主题默认色
  Color? _customCardColor;

  // ==================== 图标设置 ====================

  /// 自定义全局图标颜色；非空即表示用户覆盖了主题默认色
  Color? _customIconColor;

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

  /// 浮动按钮显示模式：auto（智能隐藏）、always（永久显示）、never（永久隐藏）
  String _floatingButtonsMode = 'auto';

  // ==================== 云同步凭据 ====================

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

  /// 10 种沉稳预设色。同一张表兼作主题色、UI 文字色与图标色，
  /// 因此每个色都必须能在浅色纸面上直接读、且作填充色时白字仍达 AA。
  static const List<Color> themeColors = [
    Color(0xFF4B4F86), // 墨蓝（默认）
    Color(0xFF725C3B), // 赭石
    Color(0xFF6C5280), // 暮紫
    Color(0xFF54623C), // 橄榄
    Color(0xFF44617E), // 雾蓝
    Color(0xFF804842), // 陶红
    Color(0xFF3E636A), // 石青
    Color(0xFF824F60), // 灰玫
    Color(0xFF3A6455), // 苔绿
    Color(0xFF71503D), // 棕褐
  ];

  /// 旧 12 色（Tailwind-500）到新色板的色相最近邻映射，下标为旧索引。
  /// 用色相而非 Lab 距离：Lab 最近邻会把「琥珀」判给「陶红」（ΔE 107.8）。
  static const List<int> _legacyPaletteHueRemap = [
    0,
    4,
    8,
    1,
    5,
    2,
    7,
    8,
    9,
    3,
    6,
    2,
  ];

  // ==================== 预设界面字体颜色 ====================

  /// UI 文字颜色预设与主题色调色板保持一致
  static const List<Color> uiFontColors = themeColors;

  // ==================== 预设编辑器文字颜色 ====================

  /// 8种精选编辑器文字颜色（适合长时间编辑阅读）
  static const List<Color> editorFontColors = [
    Color(0xFF1F2937), // 深灰（默认）- 近黑色，经典编辑器风格
    Color(0xFF2D3748), // 蓝灰 - 柔和护眼
    Color(0xFF1E3A5F), // 深蓝 - 沉稳专注
    Color(0xFF1B4332), // 深绿 - 自然清新
    Color(0xFF4A1D1D), // 深红 - 温暖复古
    Color(0xFF3B2D5F), // 深紫 - 优雅独特
    Color(0xFF374151), // 灰色 - 中等深度
    Color(0xFF0F172A), // 纯黑 - 高对比度
  ];

  // ==================== 预设全局图标颜色 ====================

  /// 全局图标颜色预设与主题色调色板保持一致
  static const List<Color> globalIconColors = themeColors;

  // ==================== Getters ====================

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get letterSpacing => _letterSpacing;
  double get paragraphSpacing => _paragraphSpacing;
  bool get autoSave => _autoSave;
  int get autoSaveInterval => _autoSaveInterval;
  bool get saveOnExit => _saveOnExit;
  String? get defaultDirectory => _defaultDirectory;
  String get workspaceName => _workspaceName;
  String? get customWorkspaceBasePath => _customWorkspaceBasePath;
  String get startupBehavior => _startupBehavior;
  String? get lastOpenedFilePath => _lastOpenedFilePath;
  int get primaryColorIndex => _primaryColorIndex;
  Color get primaryColor =>
      _customThemeColor ?? themeColors[_primaryColorIndex];
  Color? get customThemeColor => _customThemeColor;

  // 界面字体颜色 Getters
  int get uiFontColorIndex => _uiFontColorIndex;
  Color? get customUiFontColor => _customUiFontColor;

  // 编辑器文字颜色 Getters
  int get editorFontColorIndex => _editorFontColorIndex;
  Color? get customEditorFontColor => _customEditorFontColor;

  /// 强调色与墨色预设都是为浅色纸面调校的，深色表面上需压饱和并提亮才可读。
  static Color legibleOnDark(Color color) => ThemeTones.legibleOnDark(color);

  /// 预设索引越界（旧版残留或色板缩短）时夹回有效范围，避免取值抛错。
  static int _clampPaletteIndex(int index) {
    if (index < 0) return 0;
    return index >= themeColors.length ? themeColors.length - 1 : index;
  }

  /// 色板整体更换后，把已存的旧索引按色相最近邻换算一次，
  /// 否则用户选过的颜色会在升级后被静默换成不相干色相。
  /// 超出旧表长度的值不可能是旧索引，交给 [_clampPaletteIndex] 处理。
  Future<void> _remapLegacyPaletteIndices(SharedPreferences prefs) async {
    if (prefs.getBool('palette_v2_remap_done') ?? false) return;

    final legacyPrimary = prefs.getInt('primary_color_index');
    if (legacyPrimary != null &&
        legacyPrimary < _legacyPaletteHueRemap.length) {
      _primaryColorIndex = _legacyPaletteHueRemap[legacyPrimary];
      await prefs.setInt('primary_color_index', _primaryColorIndex);
    }

    final legacyUiFont = prefs.getInt('ui_font_color_index');
    if (legacyUiFont != null && legacyUiFont < _legacyPaletteHueRemap.length) {
      _uiFontColorIndex = _legacyPaletteHueRemap[legacyUiFont];
      await prefs.setInt('ui_font_color_index', _uiFontColorIndex);
    }

    await prefs.setBool('palette_v2_remap_done', true);
  }

  /// 自定义色是用户显式取的，两种模式下都原样生效；预设则按表面明暗取变体。
  static Color _resolveTextColor(
    Color? custom,
    Color preset,
    Brightness brightness,
  ) {
    if (custom != null) return custom;
    return brightness == Brightness.dark ? legibleOnDark(preset) : preset;
  }

  Color uiFontColorFor(Brightness brightness) => _resolveTextColor(
    _customUiFontColor,
    uiFontColors[_uiFontColorIndex],
    brightness,
  );

  Color editorFontColorFor(Brightness brightness) => _resolveTextColor(
    _customEditorFontColor,
    editorFontColors[_editorFontColorIndex],
    brightness,
  );

  String? get backgroundImagePath => _backgroundImagePath;
  String? get editorBackgroundImagePath => _editorBackgroundImagePath;
  bool get editorBackgroundImageExists => _editorBackgroundImageExists;
  String get backgroundEffect => _backgroundEffect;
  double get backgroundBlur => _backgroundBlur;
  double get backgroundBrightness => _backgroundBrightness;
  bool get editorBackgroundBlurEnabled => _editorBackgroundBlurEnabled;
  double get editorBackgroundBlur => _editorBackgroundBlur;
  double get editorBackgroundBrightness => _editorBackgroundBrightness;

  bool get autoCheckUpdate => _autoCheckUpdate;

  /// 当前更新规则
  String get updateChannel => _updateChannel;

  /// 自定义下载代理前缀列表（按顺序尝试）
  List<String> get updateProxies => List.unmodifiable(_updateProxies);
  double get cardOpacity => _cardOpacity;
  double get tabBarOpacity => _tabBarOpacity;
  Color? get customCardColor => _customCardColor;

  // 图标设置 Getters
  Color? get customIconColor => _customIconColor;
  int get appIconIndex => _appIconIndex;
  String get homeIconMode => _homeIconMode;
  String? get homeIconCustomPath => _homeIconCustomPath;
  String get homeTitleText => _homeTitleText;

  Locale get locale => _locale;
  int get darkThemeIndex => _darkThemeIndex;
  int get lightThemeIndex => _lightThemeIndex;
  String get uiFontFamily => _uiFontFamily;
  AppButtonStyleMode get buttonStyleMode => _buttonStyleMode;
  bool get useBorderlessButtons =>
      _buttonStyleMode == AppButtonStyleMode.softShadow;
  String get editorFontFamily => _editorFontFamily;
  String get codeFontFamily => _codeFontFamily;
  int get codeBlockThemeIndex => _codeBlockThemeIndex;

  // 云同步 Getters
  String get syncType => _syncType;
  String get floatingButtonsMode => _floatingButtonsMode;
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

  // ==================== 云同步凭据 Getters ====================

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

  /// 一次性迁移旧的「自定义颜色」格式：旧模型靠 `use_custom_*` 开关判定是否覆盖预设，
  /// 新模型只看颜色键。开关为 false 时残留的颜色值要一并删除，否则下次启动因开关键已
  /// 消失而把它当成自定义色复活。
  Future<Color?> _migrateCustomColor(
    SharedPreferences prefs, {
    required String colorKey,
    required String legacyFlagKey,
  }) async {
    final value = prefs.getInt(colorKey);
    if (!prefs.containsKey(legacyFlagKey)) {
      return value != null ? Color(value) : null;
    }
    final useCustom = prefs.getBool(legacyFlagKey) ?? false;
    await prefs.remove(legacyFlagKey);
    if (!useCustom) {
      await prefs.remove(colorKey);
      return null;
    }
    return value != null ? Color(value) : null;
  }

  Future<void> initialize() async {
    final prefs = await _getPrefs();

    // 主题设置
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];
    _primaryColorIndex = _clampPaletteIndex(
      prefs.getInt('primary_color_index') ?? 0,
    );
    _customThemeColor = await _migrateCustomColor(
      prefs,
      colorKey: 'custom_theme_color',
      legacyFlagKey: 'use_custom_theme_color',
    );

    // 界面字体颜色设置
    _uiFontColorIndex = _clampPaletteIndex(
      prefs.getInt('ui_font_color_index') ?? 0,
    );
    _customUiFontColor = await _migrateCustomColor(
      prefs,
      colorKey: 'custom_ui_font_color',
      legacyFlagKey: 'use_custom_ui_font_color',
    );
    await _remapLegacyPaletteIndices(prefs);

    // 编辑器文字颜色设置
    _editorFontColorIndex = prefs.getInt('editor_font_color_index') ?? 0;
    _customEditorFontColor = await _migrateCustomColor(
      prefs,
      colorKey: 'custom_editor_font_color',
      legacyFlagKey: 'use_custom_editor_font_color',
    );
    // 「自适应渐变」开关从未被任何渲染路径读取，连同旧键一并移除
    await prefs.remove('adaptive_gradient_enabled');
    await prefs.remove('ui_font_adaptive_gradient_enabled');
    await prefs.remove('editor_font_adaptive_gradient_enabled');

    // 编辑器设置
    _fontSize = prefs.getDouble('font_size') ?? 16.0;
    _autoSave = prefs.getBool('auto_save') ?? false;
    _autoSaveInterval = prefs.getInt('auto_save_interval') ?? 30;
    _saveOnExit = prefs.getBool('save_on_exit') ?? false;
    _lineHeight = prefs.getDouble('line_height') ?? 1.6;
    _letterSpacing = prefs.getDouble('letter_spacing') ?? 0.0;
    _paragraphSpacing = prefs.getDouble('paragraph_spacing') ?? 8.0;
    _startupBehavior = prefs.getString('startup_behavior') ?? 'restore';
    _lastOpenedFilePath = prefs.getString('last_opened_file_path');
    if (prefs.containsKey('debug_enabled')) {
      // 调试模式已整体移除，清掉遗留键避免它继续被读回
      await prefs.remove('debug_enabled');
    }
    if (prefs.containsKey('tab_bar_style')) {
      // 导航栏样式已并入「UI 风格」，这个键不再有读取方
      await prefs.remove('tab_bar_style');
    }
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
    // 异步验证背景图是否存在
    if (_editorBackgroundImagePath != null) {
      _editorBackgroundImageExists = await File(
        _editorBackgroundImagePath!,
      ).exists();
    }
    // 旧版本的 'overlay' 态在 UI 上已不可达（模糊开关只会写 'blur'/'none'），
    // 残留该值的用户无法自行关闭，统一归一为 'blur'。
    final savedEffect = prefs.getString('background_effect') ?? 'none';
    _backgroundEffect = savedEffect == 'overlay' ? 'blur' : savedEffect;
    if (savedEffect == 'overlay') {
      await prefs.setString('background_effect', 'blur');
    }
    _backgroundBlur = prefs.getDouble('background_blur') ?? 10.0;
    _backgroundBrightness = prefs.getDouble('background_brightness') ?? 1.0;
    _editorBackgroundBlurEnabled =
        prefs.getBool('editor_background_blur_enabled') ?? false;
    _editorBackgroundBlur = prefs.getDouble('editor_background_blur') ?? 10.0;
    _editorBackgroundBrightness =
        prefs.getDouble('editor_background_brightness') ?? 1.0;
    await prefs.remove('background_overlay_opacity');

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
    _updateChannel = prefs.getString('update_channel') == 'prerelease'
        ? 'prerelease'
        : 'stable';
    _updateProxies = _decodeProxies(prefs.getString('update_proxies'));

    // 底栏设置
    _cardOpacity = prefs.getDouble('card_opacity') ?? 1.0;
    _tabBarOpacity = prefs.getDouble('tab_bar_opacity') ?? 0.95;

    // 自定义卡片颜色
    _customCardColor = await _migrateCustomColor(
      prefs,
      colorKey: 'custom_card_color',
      legacyFlagKey: 'use_custom_card_color',
    );

    // 自定义全局图标颜色
    _customIconColor = await _migrateCustomColor(
      prefs,
      colorKey: 'custom_icon_color',
      legacyFlagKey: 'use_custom_icon_color',
    );

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
      orElse: () => AppButtonStyleMode.liquidGlass,
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

    // 代码块主题设置
    _codeBlockThemeIndex = prefs.getInt('code_block_theme_index') ?? 0;

    // 云同步设置
    _syncType = prefs.getString('sync_type') ?? 'webdav';
    _floatingButtonsMode = prefs.getString('floating_buttons_mode') ?? 'auto';
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

    // 莫奈配色系统已删除，此处只做一次性迁移
    final monetAccent = await _migrateMonetAccent(prefs);
    if (monetAccent != null) {
      // 莫奈此前在渲染上无条件压过自定义主题色，迁移结果显式落盘，
      // 否则二次启动 monet 键已消失，界面会回跳到一直被压制的旧自定义色。
      _customThemeColor = monetAccent;
      await prefs.setInt('custom_theme_color', monetAccent.toARGB32());
    }

    notifyListeners();
  }

  // ==================== 主题设置方法 ====================

  /// 设置主题模式
  ///
  /// [mode] ThemeMode.system / ThemeMode.light / ThemeMode.dark
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    _schedulePersist('theme_mode', mode.index);
  }

  /// 写入自定义颜色；传 null 表示清除覆盖、回落预设
  Future<void> _writeCustomColor(String key, Color? color) async {
    final prefs = await _getPrefs();
    if (color == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, color.toARGB32());
    }
  }

  /// 选择预设主题色（同时清除自定义覆盖）
  Future<void> setPrimaryColorIndex(int index) async {
    _primaryColorIndex = index;
    _customThemeColor = null;
    notifyListeners();
    _schedulePersist('primary_color_index', index);
    await _writeCustomColor('custom_theme_color', null);
  }

  /// 设置自定义主题色；传 null 恢复预设
  Future<void> setCustomThemeColor(Color? color) async {
    _customThemeColor = color;
    notifyListeners();
    await _writeCustomColor('custom_theme_color', color);
  }

  // ==================== 界面字体颜色设置方法 ====================

  /// 选择预设界面字体颜色（同时清除自定义覆盖）
  Future<void> setUiFontColorIndex(int index) async {
    _uiFontColorIndex = index;
    _customUiFontColor = null;
    notifyListeners();
    _schedulePersist('ui_font_color_index', index);
    await _writeCustomColor('custom_ui_font_color', null);
  }

  /// 设置自定义界面字体颜色；传 null 恢复预设
  Future<void> setCustomUiFontColor(Color? color) async {
    _customUiFontColor = color;
    notifyListeners();
    await _writeCustomColor('custom_ui_font_color', color);
  }

  // ==================== 编辑器文字颜色设置方法 ====================

  /// 选择预设编辑器文字颜色（同时清除自定义覆盖）
  Future<void> setEditorFontColorIndex(int index) async {
    _editorFontColorIndex = index;
    _customEditorFontColor = null;
    notifyListeners();
    _schedulePersist('editor_font_color_index', index);
    await _writeCustomColor('custom_editor_font_color', null);
  }

  /// 设置自定义编辑器文字颜色；传 null 恢复预设
  Future<void> setCustomEditorFontColor(Color? color) async {
    _customEditorFontColor = color;
    notifyListeners();
    await _writeCustomColor('custom_editor_font_color', color);
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
        } catch (e) {
          appDebugLog('操作失败: $e');
        }
      }
      _backgroundImagePath = null;
      final prefs = await _getPrefs();
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
        } catch (e) {
          appDebugLog('操作失败: $e');
        }
      }

      _backgroundImagePath = destPath;
      final prefs = await _getPrefs();
      await prefs.setString('background_image_path', destPath);
      notifyListeners();
    } catch (e) {
      // 如果复制失败，直接使用原路径（回退方案）
      _backgroundImagePath = path;
      final prefs = await _getPrefs();
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
        } catch (e) {
          appDebugLog('操作失败: $e');
        }
      }
      _editorBackgroundImagePath = null;
      _editorBackgroundImageExists = false;
      final prefs = await _getPrefs();
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
        } catch (e) {
          appDebugLog('操作失败: $e');
        }
      }

      _editorBackgroundImagePath = destPath;
      _editorBackgroundImageExists = true;
      final prefs = await _getPrefs();
      await prefs.setString('editor_background_image_path', destPath);
      notifyListeners();
    } catch (e) {
      // 如果复制失败，直接使用原路径（回退方案）
      _editorBackgroundImagePath = path;
      _editorBackgroundImageExists = await File(path).exists();
      final prefs = await _getPrefs();
      await prefs.setString('editor_background_image_path', path);
      notifyListeners();
    }
  }

  /// 设置背景效果
  Future<void> setBackgroundEffect(String effect) async {
    _backgroundEffect = effect;
    notifyListeners();
    _schedulePersist('background_effect', effect);
  }

  /// 设置模糊强度
  Future<void> setBackgroundBlur(double blur) async {
    _backgroundBlur = blur;
    notifyListeners();
    _schedulePersist('background_blur', blur);
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
    _schedulePersist('background_brightness', brightness);
  }

  /// 设置编辑器背景模糊开关
  Future<void> setEditorBackgroundBlurEnabled(bool enabled) async {
    _editorBackgroundBlurEnabled = enabled;
    notifyListeners();
    _schedulePersist('editor_background_blur_enabled', enabled);
  }

  /// 设置编辑器背景模糊强度
  Future<void> setEditorBackgroundBlur(double blur) async {
    _editorBackgroundBlur = blur;
    notifyListeners();
    _schedulePersist('editor_background_blur', blur);
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
    _schedulePersist('editor_background_brightness', brightness);
  }

  // ==================== 编辑器设置方法 ====================

  /// 设置编辑器字体大小
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    _schedulePersist('font_size', size);
  }

  /// 设置是否启用自动保存
  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    notifyListeners();
    _schedulePersist('auto_save', value);
  }

  /// 设置自动保存间隔
  Future<void> setAutoSaveInterval(int seconds) async {
    _autoSaveInterval = seconds;
    notifyListeners();
    _schedulePersist('auto_save_interval', seconds);
  }

  /// 设置退出文档时是否自动保存
  Future<void> setSaveOnExit(bool value) async {
    _saveOnExit = value;
    notifyListeners();
    _schedulePersist('save_on_exit', value);
  }

  /// 设置行高
  Future<void> setLineHeight(double height) async {
    _lineHeight = height;
    notifyListeners();
    _schedulePersist('line_height', height);
  }

  /// 设置字间距
  Future<void> setLetterSpacing(double spacing) async {
    _letterSpacing = spacing;
    notifyListeners();
    _schedulePersist('letter_spacing', spacing);
  }

  /// 设置段落间距
  Future<void> setParagraphSpacing(double spacing) async {
    _paragraphSpacing = spacing;
    notifyListeners();
    _schedulePersist('paragraph_spacing', spacing);
  }

  /// 设置启动行为
  Future<void> setStartupBehavior(String behavior) async {
    _startupBehavior = behavior;
    notifyListeners();
    _schedulePersist('startup_behavior', behavior);
  }

  /// 设置上次打开的文件路径
  Future<void> setLastOpenedFilePath(String? path) async {
    _lastOpenedFilePath = path;
    notifyListeners();
    if (path != null) {
      _schedulePersist('last_opened_file_path', path);
    } else {
      final prefs = await _getPrefs();
      await prefs.remove('last_opened_file_path');
    }
  }

  /// 设置默认目录
  Future<void> setDefaultDirectory(String? path) async {
    _defaultDirectory = path;
    notifyListeners();
    final prefs = await _getPrefs();
    if (path != null) {
      await prefs.setString('default_directory', path);
    } else {
      await prefs.remove('default_directory');
    }
  }

  /// 设置工作区文件夹名称
  Future<void> setWorkspaceName(String name) async {
    _workspaceName = name;
    notifyListeners();
    _schedulePersist('workspace_name', name);
  }

  /// 设置自定义工作区基础路径
  Future<void> setCustomWorkspaceBasePath(String? path) async {
    _customWorkspaceBasePath = path;
    notifyListeners();
    final prefs = await _getPrefs();
    if (path != null && path.isNotEmpty) {
      await prefs.setString('custom_workspace_base_path', path);
    } else {
      await prefs.remove('custom_workspace_base_path');
    }
  }

  // ==================== 语言设置方法 ====================

  /// 设置应用语言
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    _schedulePersist('locale', locale.languageCode);
  }

  // ==================== 更新设置方法 ====================

  /// 设置启动时是否自动检查更新
  Future<void> setAutoCheckUpdate(bool value) async {
    _autoCheckUpdate = value;
    notifyListeners();
    _schedulePersist('auto_check_update', value);
  }

  /// 设置更新规则
  Future<void> setUpdateChannel(String value) async {
    _updateChannel = value == 'prerelease' ? 'prerelease' : 'stable';
    notifyListeners();
    _schedulePersist('update_channel', _updateChannel);
  }

  /// 设置自定义下载代理列表；去空行、去重，顺序即尝试顺序
  Future<void> setUpdateProxies(List<String> proxies) async {
    _updateProxies = _normalizeProxies(proxies);
    notifyListeners();
    _schedulePersist('update_proxies', jsonEncode(_updateProxies));
  }

  /// 解析持久化的代理列表，损坏数据按空处理
  static List<String> _decodeProxies(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return _normalizeProxies(decoded.whereType<String>().toList());
    } catch (_) {
      return [];
    }
  }

  static List<String> _normalizeProxies(List<String> items) {
    final result = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || result.contains(trimmed)) continue;
      result.add(trimmed);
    }
    return result;
  }

  /// 设置卡片透明度
  Future<void> setCardOpacity(double opacity) async {
    _cardOpacity = opacity;
    notifyListeners();
    _schedulePersist('card_opacity', opacity);
  }

  /// 设置底部导航栏透明度
  Future<void> setTabBarOpacity(double opacity) async {
    _tabBarOpacity = opacity;
    notifyListeners();
    _schedulePersist('tab_bar_opacity', opacity);
  }

  /// 设置自定义卡片颜色；传 null 恢复主题默认
  Future<void> setCustomCardColor(Color? color) async {
    _customCardColor = color;
    notifyListeners();
    await _writeCustomColor('custom_card_color', color);
  }

  // ==================== 图标设置方法 ====================

  /// 设置自定义全局图标颜色；传 null 恢复主题默认
  Future<void> setCustomIconColor(Color? color) async {
    _customIconColor = color;
    notifyListeners();
    await _writeCustomColor('custom_icon_color', color);
  }

  /// 设置桌面图标索引（0=默认, 1=icon2）
  Future<void> setAppIconIndex(int index) async {
    _appIconIndex = index;
    notifyListeners();
    _schedulePersist('app_icon_index', index);
  }

  /// 设置主页图标模式
  Future<void> setHomeIconMode(String mode) async {
    _homeIconMode = mode;
    notifyListeners();
    _schedulePersist('home_icon_mode', mode);
  }

  /// 设置主页自定义图标路径
  Future<void> setHomeIconCustomPath(String? path) async {
    _homeIconCustomPath = path;
    notifyListeners();
    final prefs = await _getPrefs();
    if (path != null) {
      await prefs.setString('home_icon_custom_path', path);
    } else {
      await prefs.remove('home_icon_custom_path');
    }
  }

  /// 设置主页标题文字（允许为空）
  Future<void> setHomeTitleText(String text) async {
    _homeTitleText = text.trim();
    notifyListeners();
    _schedulePersist('home_title_text', text.trim());
  }

  // ==================== 夜间主题和字体设置方法 ====================

  /// 设置夜间主题索引
  Future<void> setDarkThemeIndex(int index) async {
    _darkThemeIndex = index;
    notifyListeners();
    _schedulePersist('dark_theme_index', index);
  }

  /// 设置浅色主题索引
  Future<void> setLightThemeIndex(int index) async {
    _lightThemeIndex = index;
    notifyListeners();
    _schedulePersist('light_theme_index', index);
  }

  /// 设置按钮风格
  Future<void> setButtonStyleMode(AppButtonStyleMode mode) async {
    _buttonStyleMode = mode;
    notifyListeners();
    _schedulePersist('button_style_mode', mode.name);
  }

  /// 设置 UI 字体
  Future<void> setUiFontFamily(String fontFamily) async {
    _uiFontFamily = fontFamily;
    notifyListeners();
    _schedulePersist('font_family_ui', fontFamily);
  }

  /// 设置编辑器字体
  Future<void> setEditorFontFamily(String fontFamily) async {
    _editorFontFamily = fontFamily;
    notifyListeners();
    _schedulePersist('font_family_editor', fontFamily);
  }

  /// 设置代码块字体
  Future<void> setCodeFontFamily(String fontFamily) async {
    _codeFontFamily = fontFamily;
    notifyListeners();
    _schedulePersist('font_family_code', fontFamily);
  }

  /// 设置代码块主题索引
  Future<void> setCodeBlockThemeIndex(int index) async {
    _codeBlockThemeIndex = index;
    notifyListeners();
    _schedulePersist('code_block_theme_index', index);
  }

  // ==================== 云同步设置方法 ====================

  /// 设置同步类型
  Future<void> setSyncType(String type) async {
    _syncType = type;
    notifyListeners();
    _schedulePersist('sync_type', type);
  }

  /// 设置 WebDAV 服务器地址
  Future<void> setWebdavUrl(String url) async {
    _webdavUrl = url;
    notifyListeners();
    _schedulePersist('webdav_url', url);
  }

  /// 设置 WebDAV 用户名
  Future<void> setWebdavUsername(String username) async {
    _webdavUsername = username;
    notifyListeners();
    _schedulePersist('webdav_username', username);
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
    notifyListeners();
    _schedulePersist('ftp_url', cleanUrl);
  }

  /// 设置 FTP 用户名
  Future<void> setFtpUsername(String username) async {
    _ftpUsername = username;
    notifyListeners();
    _schedulePersist('ftp_username', username);
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
    notifyListeners();
    _schedulePersist('sync_folder_name', folderName);
  }

  /// 设置云端文件夹路径前缀
  Future<void> setSyncRemotePath(String path) async {
    _syncRemotePath = path;
    notifyListeners();
    _schedulePersist('sync_remote_path', path);
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
    notifyListeners();
    _schedulePersist('auto_sync_enabled', enabled);
  }

  /// 设置浮动按钮显示模式
  Future<void> setFloatingButtonsMode(String mode) async {
    if (_floatingButtonsMode == mode) return;
    _floatingButtonsMode = mode;
    notifyListeners();
    _schedulePersist('floating_buttons_mode', mode);
  }

  /// 更新上次同步时间
  Future<void> updateLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    notifyListeners();
    _schedulePersist('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);
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

    final prefs = await _getPrefs();
    await prefs.setString('webdav_url', url);
    await prefs.setString('webdav_username', username);
    // 密码使用安全存储
    await _secureStorage.write(key: 'webdav_password', value: password);
    notifyListeners();
  }

  /// 一次性迁移已删除的莫奈配色系统。
  ///
  /// 莫奈在渲染上整块替换 colorScheme，用户实际看到的是它派生出的 primary，
  /// 因此把激活方案的 primary 迁成「自定义主题色」，避免升级后界面突然变色。
  /// 三个 monet 键无条件删除，保证只迁移一次。
  Future<Color?> _migrateMonetAccent(SharedPreferences prefs) async {
    final enabled = prefs.getBool('monet_enabled') ?? false;
    final activeId = prefs.getString('active_monet_config_id');
    final rawConfigs = prefs.getString('saved_monet_configs');
    await prefs.remove('monet_enabled');
    await prefs.remove('active_monet_config_id');
    await prefs.remove('saved_monet_configs');

    if (!enabled ||
        activeId == null ||
        rawConfigs == null ||
        rawConfigs.isEmpty) {
      return null;
    }
    try {
      final configs = json.decode(rawConfigs) as List<dynamic>;
      final active = configs.whereType<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == activeId,
      );
      final scheme = active['scheme'] as Map<String, dynamic>?;
      if (scheme == null) return null;
      // 取用户当时真正看到的那一套：深色用 darkScheme，其余用 lightScheme
      final bucket = _themeMode == ThemeMode.dark
          ? 'darkScheme'
          : 'lightScheme';
      final primary = (scheme[bucket] as Map<String, dynamic>?)?['primary'];
      return primary is int ? Color(primary) : null;
    } catch (_) {
      return null;
    }
  }
}
