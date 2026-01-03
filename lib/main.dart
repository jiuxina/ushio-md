/// ============================================================================
/// 汐 - Markdown 编辑器
/// ============================================================================
/// 
/// 一款简洁优雅的移动端 Markdown 编辑器应用。
/// 
/// 功能特性：
/// - 📝 Markdown 编辑与预览
/// - 📁 文件浏览与管理
/// - 🎨 主题切换与个性化设置
/// - 💾 自动保存功能
/// 
/// 技术栈：
/// - Flutter - 跨平台 UI 框架
/// - Provider - 状态管理
/// - flutter_markdown - Markdown 渲染
/// 
/// @author jiuxina
/// @version 1.0.0
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/file_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';
import 'utils/constants.dart';

/// ============================================================================
/// 应用入口
/// ============================================================================

/// 应用程序入口函数
/// 
/// 初始化 Flutter 绑定并启动应用
void main() async {
  // 确保 Flutter 引擎初始化完成（异步操作前必须调用）
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // 注册全局状态提供者
      providers: [
        // 文件管理状态（文件列表、最近文件、固定文件等）
        ChangeNotifierProvider(create: (_) => FileProvider()),
        // 设置状态（主题、字体、自动保存等）
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          // 获取用户选择的主题色
          final primaryColor = settings.primaryColor;
          
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
            locale: const Locale('zh', 'CN'),  // 默认使用中文
            theme: _buildLightTheme(primaryColor),  // 浅色主题
            darkTheme: _buildDarkTheme(primaryColor),  // 深色主题
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
  ThemeData _buildLightTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,  // 启用 Material 3 设计
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: AppConstants.accentColor,
        surface: AppConstants.lightSurface,
        error: AppConstants.errorColor,
      ),
      scaffoldBackgroundColor: AppConstants.lightBackground,
      
      // AppBar 主题
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.lightSurface,
        foregroundColor: AppConstants.lightText,
        elevation: 0,  // 无阴影
        centerTitle: false,  // 标题左对齐
      ),
      
      // 卡片主题
      cardTheme: CardThemeData(
        color: AppConstants.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: Colors.grey.shade200),
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
        fillColor: AppConstants.lightBackground,
      ),
      
      // 分割线主题
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
    );
  }

  /// 构建深色主题
  /// 
  /// [primaryColor] 用户选择的主题色
  ThemeData _buildDarkTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: AppConstants.accentColor,
        surface: AppConstants.darkSurface,
        error: AppConstants.errorColor,
      ),
      scaffoldBackgroundColor: AppConstants.darkBackground,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.darkSurface,
        foregroundColor: AppConstants.darkText,
        elevation: 0,
        centerTitle: false,
      ),
      
      cardTheme: CardThemeData(
        color: AppConstants.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: Colors.grey.shade800),
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
        fillColor: AppConstants.darkBackground,
      ),
      
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
      ),
    );
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
      Future.delayed(const Duration(milliseconds: 2000)),
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
                                  .withOpacity(0.4),
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
