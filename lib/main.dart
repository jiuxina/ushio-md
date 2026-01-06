// ============================================================================
// 汐 - Markdown 编辑器
// ============================================================================
// 
// 一款简洁优雅的移动端 Markdown 编辑器应用。
// 
// 功能特性：
// - 📝 Markdown 编辑与预览
// - 📁 文件浏览与管理
// - 🎨 主题切换与个性化设置
// - 💾 自动保存功能
// 
// 技术栈：
// - Flutter - 跨平台 UI 框架
// - Provider - 状态管理
// - flutter_markdown - Markdown 渲染
// 
// @author jiuxina
// @version 1.0.0
// ============================================================================



import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/file_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/plugin_provider.dart';
import 'plugins/extensions/theme_extension.dart';
import 'screens/main_screen.dart';
import 'utils/constants.dart';

/// ============================================================================
/// 应用入口
/// ============================================================================

/// 应用程序入口函数
/// 
/// 初始化 Flutter 绑定并启动应用
import 'services/font_service.dart';
import 'services/my_files_service.dart';

/// 应用程序入口函数
/// 
/// 初始化 Flutter 绑定并启动应用
void main() async {
  // 确保 Flutter 引擎初始化完成（异步操作前必须调用）
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化"我的文件"工作区（创建 Ushio-MD 目录）
  final myFilesService = MyFilesService();
  await myFilesService.initWorkspace();

  // 加载已安装的自定义字体（包括手动下载的 Google 字体）
  await FontService.loadAllCustomFonts();
  
  // 初始化插件系统（加载已安装的插件）
  final pluginProvider = PluginProvider();
  await pluginProvider.initialize();
  
  runApp(MyApp(pluginProvider: pluginProvider));
}

/// ============================================================================
/// 主应用组件
/// ============================================================================

/// 应用根组件
/// 
/// 职责：
/// - 配置 Provider 状态管理
/// - 设置主题（浅色/深色）
/// - 配置 MaterialApp
class MyApp extends StatelessWidget {
  final PluginProvider pluginProvider;
  
  const MyApp({super.key, required this.pluginProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // 注册全局状态提供者
      providers: [
        // 文件管理状态（文件列表、最近文件、固定文件等）
        ChangeNotifierProvider(create: (_) => FileProvider()),
        // 设置状态（主题、字体、自动保存等）
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        // 插件管理状态（已安装/已启用插件、扩展点等）- 使用预初始化的实例
        ChangeNotifierProvider.value(value: pluginProvider),
      ],
      child: Consumer2<SettingsProvider, PluginProvider>(
        builder: (context, settings, pluginProvider, child) {
          // 获取用户选择的主题色
          Color primaryColor = settings.primaryColor;
          
          // 获取插件主题扩展
          final themeExtensions = pluginProvider.getThemeExtensions();
          ThemeColors? pluginLightColors;
          ThemeColors? pluginDarkColors;
          
          // 使用最后一个启用的插件主题覆盖
          if (themeExtensions.isNotEmpty) {
            final ext = themeExtensions.last;
            pluginLightColors = ext.lightColors;
            pluginDarkColors = ext.darkColors;
            
            // 如果插件定义了主题色，优先使用插件的主题色
            if (settings.themeMode == ThemeMode.light && pluginLightColors?.primary != null) {
              primaryColor = pluginLightColors!.primary!;
            } else if (settings.themeMode == ThemeMode.dark && pluginDarkColors?.primary != null) {
              primaryColor = pluginDarkColors!.primary!;
            } else if (settings.themeMode == ThemeMode.system) {
              final brightness = MediaQuery.platformBrightnessOf(context);
              if (brightness == Brightness.light && pluginLightColors?.primary != null) {
                primaryColor = pluginLightColors!.primary!;
              } else if (brightness == Brightness.dark && pluginDarkColors?.primary != null) {
                primaryColor = pluginDarkColors!.primary!;
              }
            }
          }

          // 获取字体设置（System 表示使用系统默认）
          final fontFamily = settings.uiFontFamily == 'System' ? null : settings.uiFontFamily;
          // 获取主题配色方案索引
          final darkThemeIndex = settings.darkThemeIndex;
          final lightThemeIndex = settings.lightThemeIndex;
          
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,  // 隐藏调试标识
            // 中文本地化支持（实现编辑菜单中文化）
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),  // 简体中文
              Locale('en', 'US'),  // 英文
            ],
            locale: settings.locale,  // 使用动态语言设置
            theme: _buildLightTheme(primaryColor, fontFamily, lightThemeIndex, pluginLightColors),  // 浅色主题
            darkTheme: _buildDarkTheme(primaryColor, darkThemeIndex, fontFamily, pluginDarkColors),  // 深色主题
            themeMode: settings.themeMode,  // 主题模式（跟随系统/浅色/深色）
            home: const MainScreen(),  // 主页面
          );
        },
      ),
    );
  }

  /// 构建浅色主题
  /// 
  /// [primaryColor] 用户选择的主题色
  /// [fontFamily] 用户选择的字体（null 表示系统默认）
  /// [pluginColors] 插件自定义颜色
  ThemeData _buildLightTheme(Color primaryColor, String? fontFamily, int lightThemeIndex, ThemeColors? pluginColors) {
    // 获取选中的浅色主题配色方案
    final scheme = AppConstants.lightThemeSchemes[lightThemeIndex];
    
    // 构建基础 ColorScheme
    var colorScheme = ColorScheme.light(
      primary: primaryColor,
      secondary: AppConstants.accentColor,
      surface: scheme.surface,
      error: AppConstants.errorColor,
    );
    
    // 应用插件颜色覆盖
    if (pluginColors != null) {
      colorScheme = pluginColors.applyTo(colorScheme);
    }
    
    // 构建基础主题
    ThemeData theme = ThemeData(
      useMaterial3: true,  // 启用 Material 3 设计
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scheme.background,
      
      // AppBar 主题
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.text,
        elevation: 0,  // 无阴影
        centerTitle: false,  // 标题左对齐
      ),
      
      // 卡片主题
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: scheme.textSecondary.withValues(alpha: 0.2)),
        ),
      ),
      
      // 浮动按钮主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
        filled: true,
        fillColor: scheme.background,
      ),
      
      // 分割线主题
      dividerTheme: DividerThemeData(
        color: scheme.textSecondary.withValues(alpha: 0.2),
        thickness: 1,
      ),
      
      // 下拉菜单主题
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: scheme.text),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevation: const WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),
      
      // 弹出菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
    );
    
    // 应用字体
    if (fontFamily != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: fontFamily),
      );
    }
    
    return theme;
  }

  /// 构建深色主题
  /// 
  /// [primaryColor] 用户选择的主题色
  /// [darkThemeIndex] 夜间主题配色方案索引
  /// [fontFamily] 用户选择的字体（null 表示系统默认）
  /// [pluginColors] 插件自定义颜色
  ThemeData _buildDarkTheme(Color primaryColor, int darkThemeIndex, String? fontFamily, ThemeColors? pluginColors) {
    // 获取选中的夜间主题配色方案
    final scheme = AppConstants.darkThemeSchemes[darkThemeIndex];
    
    // 构建基础 ColorScheme
    var colorScheme = ColorScheme.dark(
      primary: primaryColor,
      secondary: AppConstants.accentColor,
      surface: scheme.surface,
      error: AppConstants.errorColor,
    );
    
    // 应用插件颜色覆盖
    if (pluginColors != null) {
      colorScheme = pluginColors.applyTo(colorScheme);
    }
    
    // 构建基础主题
    ThemeData theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scheme.background,
      
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.text,
        elevation: 0,
        centerTitle: false,
      ),
      
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: scheme.textSecondary.withValues(alpha: 0.3)),

        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
        filled: true,
        fillColor: scheme.background,
      ),
      
      dividerTheme: DividerThemeData(
        color: scheme.textSecondary.withValues(alpha: 0.3),

        thickness: 1,
      ),
      
      // 文本主题（使用夜间主题配色）
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: scheme.text),
        bodyMedium: TextStyle(color: scheme.text),
        bodySmall: TextStyle(color: scheme.textSecondary),
        titleLarge: TextStyle(color: scheme.text),
        titleMedium: TextStyle(color: scheme.text),
        titleSmall: TextStyle(color: scheme.textSecondary),
      ),
      
      // 下拉菜单主题
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: scheme.text),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevation: const WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),
      
      // 弹出菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
    );
    
    // 应用字体
    if (fontFamily != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: fontFamily),
      );
    }
    
    return theme;
  }
}

/// ============================================================================
/// 启动页组件（暂未使用，保留供后续启用）
/// ============================================================================

/// 动画启动页
/// 
/// 显示应用 Logo 和名称的动画效果
/// 初始化完成后跳转到主页面
/// 
/// 注意：当前版本直接进入主页面，此组件保留供后续使用
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ==================== 动画控制器 ====================
  
  late AnimationController _logoController;   // Logo 动画控制器
  late AnimationController _textController;   // 文字动画控制器
  late Animation<double> _logoScale;          // Logo 缩放动画
  late Animation<double> _logoOpacity;        // Logo 透明度动画
  late Animation<double> _textOpacity;        // 文字透明度动画
  late Animation<Offset> _textSlide;          // 文字滑入动画

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  /// 配置入场动画
  void _setupAnimations() {
    // Logo 动画：800ms，弹性效果
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 文字动画：600ms
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Logo 从 0.5x 放大到 1x，带弹性效果
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Logo 透明度从 0 到 1
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // 文字透明度从 0 到 1
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    // 文字从下方滑入
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // 动画顺序：Logo 完成后播放文字动画
    _logoController.forward().then((_) {
      _textController.forward();
    });
  }

  /// 初始化应用数据
  /// 
  /// 并行执行：
  /// - 文件提供者初始化
  /// - 设置提供者初始化
  /// - 最小等待 2 秒（确保用户看到启动页）
  Future<void> _initializeApp() async {
    final fileProvider = context.read<FileProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    await Future.wait([
      fileProvider.initialize(),
      settingsProvider.initialize(),
      Future.delayed(const Duration(milliseconds: 500)),
    ]);

    // 跳转到主页面（带淡出动画）
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        // 渐变背景
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),  // 深色渐变起点
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f23),  // 深色渐变终点
                  ]
                : [
                    const Color(0xFFf8f9ff),  // 浅色渐变起点
                    const Color(0xFFe8eeff),
                    const Color(0xFFdde4ff),  // 浅色渐变终点
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ==================== Logo 动画 ====================
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.4),

                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            'app.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // ==================== 应用名称动画 ====================
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        AppConstants.appName,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppConstants.appDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // ==================== 加载指示器 ====================
              FadeTransition(
                opacity: _textOpacity,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
