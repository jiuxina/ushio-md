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
// @version 1.3.0
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';
import 'providers/file_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';
import 'services/font_service.dart';
import 'services/my_files_service.dart';
import 'utils/app_style.dart';
import 'utils/constants.dart';
import 'widgets/global_particle_overlay.dart';

/// ============================================================================
/// 应用入口
/// ============================================================================

/// 应用程序入口函数
///
/// 初始化 Flutter 绑定并启动应用
void main() async {
  // 确保 Flutter 引擎初始化完成（异步操作前必须调用）
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器（仅桌面端）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal, // We'll use custom title bar
      title: '汐',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 初始化"我的文件"工作区（创建 Ushio-MD 目录）
  final myFilesService = MyFilesService();
  await myFilesService.initWorkspace();

  // 加载已安装的自定义字体（包括手动下载的 Google 字体）
  await FontService.loadAllCustomFonts();

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
          Color primaryColor = settings.primaryColor;

          // 获取界面字体颜色
          Color uiFontColor = settings.uiFontColor;

          // 获取字体设置（System 表示使用系统默认）
          final fontFamily = settings.uiFontFamily == 'System'
              ? null
              : settings.uiFontFamily;
          // 获取主题配色方案索引
          final darkThemeIndex = settings.darkThemeIndex;
          final lightThemeIndex = settings.lightThemeIndex;

          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false, // 隐藏调试标识
            // 中文本地化支持（实现编辑菜单中文化）
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh'), // 简体中文
              Locale('en'), // 英文
            ],
            locale: settings.locale, // 使用动态语言设置
            // 确保 locale 正确匹配
            localeResolutionCallback: (locale, supportedLocales) {
              if (locale == null) {
                return const Locale('zh');
              }
              // 首先尝试完全匹配
              for (final supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
              // 默认返回中文
              return const Locale('zh');
            },
            theme: _buildLightTheme(
              primaryColor,
              uiFontColor,
              fontFamily,
              lightThemeIndex,
              settings.buttonStyleMode,
              settings.cardOpacity,
              settings.customCardColor,
              settings.useCustomCardColor,
            ), // 浅色主题
            darkTheme: _buildDarkTheme(
              primaryColor,
              uiFontColor,
              darkThemeIndex,
              fontFamily,
              settings.buttonStyleMode,
              settings.cardOpacity,
              settings.customCardColor,
              settings.useCustomCardColor,
            ), // 深色主题
            themeMode: settings.themeMode, // 主题模式（跟随系统/浅色/深色）
            builder: (context, child) {
              return GlobalParticleOverlay(
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const MainScreen(), // 主页面
          );
        },
      ),
    );
  }

  /// 构建浅色主题
  ///
  /// [primaryColor] 用户选择的主题色
  /// [uiFontColor] 用户选择的界面字体颜色
  /// [fontFamily] 用户选择的字体（null 表示系统默认）
  ThemeData _buildLightTheme(
    Color primaryColor,
    Color uiFontColor,
    String? fontFamily,
    int lightThemeIndex,
    AppButtonStyleMode buttonStyleMode,
    double cardOpacity,
    Color? customCardColor,
    bool useCustomCardColor,
  ) {
    final scheme = AppConstants.lightThemeSchemes[lightThemeIndex];

    final colorScheme = ColorScheme.light(
      primary: primaryColor,
      secondary: AppConstants.accentColor,
      surface: scheme.surface,
      error: AppConstants.errorColor,
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      backgroundColor: scheme.background,
      textColor: uiFontColor,
      textSecondaryColor: scheme.textSecondary,
      fontFamily: fontFamily,
      buttonStyleMode: buttonStyleMode,
      cardOpacity: cardOpacity,
      customCardColor: customCardColor,
      useCustomCardColor: useCustomCardColor,
    );
  }

  /// 构建深色主题
  ///
  /// [primaryColor] 用户选择的主题色
  /// [uiFontColor] 用户选择的界面字体颜色
  /// [darkThemeIndex] 夜间主题配色方案索引
  /// [fontFamily] 用户选择的字体（null 表示系统默认）
  ThemeData _buildDarkTheme(
    Color primaryColor,
    Color uiFontColor,
    int darkThemeIndex,
    String? fontFamily,
    AppButtonStyleMode buttonStyleMode,
    double cardOpacity,
    Color? customCardColor,
    bool useCustomCardColor,
  ) {
    final scheme = AppConstants.darkThemeSchemes[darkThemeIndex];

    final colorScheme = ColorScheme.dark(
      primary: primaryColor,
      secondary: AppConstants.accentColor,
      surface: scheme.surface,
      error: AppConstants.errorColor,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      backgroundColor: scheme.background,
      textColor: uiFontColor,
      textSecondaryColor: scheme.textSecondary,
      fontFamily: fontFamily,
      buttonStyleMode: buttonStyleMode,
      cardOpacity: cardOpacity,
      customCardColor: customCardColor,
      useCustomCardColor: useCustomCardColor,
    );
  }

  ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color backgroundColor,
    required Color textColor,
    required Color textSecondaryColor,
    required String? fontFamily,
    required AppButtonStyleMode buttonStyleMode,
    required double cardOpacity,
    Color? customCardColor,
    bool useCustomCardColor = false,
  }) {
    final effectiveColorScheme = _applyGlobalCardOpacity(
      colorScheme,
      cardOpacity,
      customCardColor: customCardColor,
      useCustomCardColor: useCustomCardColor,
    );
    final appStyle = AppStyleTheme.resolve(
      brightness: brightness,
      colorScheme: effectiveColorScheme,
      textSecondary: textSecondaryColor,
      buttonStyleMode: buttonStyleMode,
      cardOpacity: cardOpacity,
      customCardColor: customCardColor,
      useCustomCardColor: useCustomCardColor,
    );

    final buttonForeground = appStyle.useBorderlessButtons
        ? textColor
        : Colors.white;
    final buttonBackground = appStyle.useBorderlessButtons
        ? appStyle.strongSurface
        : effectiveColorScheme.primary.withValues(alpha: appStyle.cardOpacity);

    ThemeData theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: effectiveColorScheme,
      scaffoldBackgroundColor: backgroundColor,
      extensions: [appStyle],
      appBarTheme: AppBarTheme(
        backgroundColor: appStyle.scaledSurfaceColor(
          effectiveColorScheme,
          alpha: 0.92,
        ),
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: appStyle.cardSurfaceColor(effectiveColorScheme),
        elevation: appStyle.useBorderlessButtons ? 4 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(
            color: appStyle.useBorderlessButtons
                ? Colors.transparent
                : textSecondaryColor.withValues(
                    alpha: brightness == Brightness.dark ? 0.3 : 0.2,
                  ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              foregroundColor: buttonForeground,
              backgroundColor: buttonBackground,
              disabledBackgroundColor: buttonBackground.withValues(alpha: 0.45),
              disabledForegroundColor: buttonForeground.withValues(alpha: 0.55),
              elevation: appStyle.useBorderlessButtons ? 4 : 0,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: appStyle.useBorderlessButtons
                      ? Colors.transparent
                      : colorScheme.primary,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appStyle.useBorderlessButtons
              ? textColor
              : colorScheme.primary,
          backgroundColor: appStyle.useBorderlessButtons
              ? appStyle.strongSurface
              : Colors.transparent,
          side: BorderSide(
            color: appStyle.useBorderlessButtons
                ? Colors.transparent
                : appStyle.outlineColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: buttonForeground,
          backgroundColor: buttonBackground,
          elevation: appStyle.useBorderlessButtons ? 4 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: appStyle.useBorderlessButtons
                  ? Colors.transparent
                  : colorScheme.primary,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: appStyle.useBorderlessButtons
              ? textColor
              : colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: appStyle.useBorderlessButtons
              ? appStyle.strongSurface
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonBackground,
        foregroundColor: buttonForeground,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appStyle.useBorderlessButtons
            ? appStyle.mutedSurface
            : backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _buildInputBorder(appStyle, textSecondaryColor),
        enabledBorder: _buildInputBorder(appStyle, textSecondaryColor),
        focusedBorder: _buildInputBorder(appStyle, colorScheme.primary),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondaryColor.withValues(
          alpha: appStyle.useBorderlessButtons
              ? 0.1
              : brightness == Brightness.dark
              ? 0.3
              : 0.2,
        ),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: appStyle.scaledSurfaceColor(
          effectiveColorScheme,
          alpha: 0.95,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: appStyle.scaledSurfaceColor(
          effectiveColorScheme,
          alpha: 0.95,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: appStyle.scaledSurfaceColor(effectiveColorScheme, alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: appStyle.useBorderlessButtons ? 0 : 8,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: textColor),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            appStyle.scaledSurfaceColor(effectiveColorScheme, alpha: 0.95),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevation: WidgetStatePropertyAll(
            appStyle.useBorderlessButtons ? 0 : 8,
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: appStyle.scaledSurfaceColor(
          effectiveColorScheme,
          alpha: 0.95,
        ),
        contentTextStyle: TextStyle(color: textColor),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: textSecondaryColor),
        titleLarge: TextStyle(color: textColor),
        titleMedium: TextStyle(color: textColor),
        titleSmall: TextStyle(color: textSecondaryColor),
      ),
    );

    if (fontFamily != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: fontFamily),
      );
    }

    return theme;
  }

  /// 应用全局卡片样式（透明度和自定义颜色）
  ///
  /// 将卡片透明度和自定义颜色应用到 ColorScheme 的所有 surface 相关颜色，
  /// 确保所有使用 colorScheme.surface 的组件都能获得一致的卡片样式。
  ColorScheme _applyGlobalCardOpacity(
    ColorScheme colorScheme,
    double cardOpacity, {
    Color? customCardColor,
    bool useCustomCardColor = false,
  }) {
    // 应用透明度，如果启用自定义颜色则使用自定义颜色作为基础
    Color applyStyle(Color originalColor) {
      final baseColor = useCustomCardColor && customCardColor != null
          ? customCardColor
          : originalColor;
      return baseColor.withValues(alpha: cardOpacity);
    }

    return colorScheme.copyWith(
      surface: applyStyle(colorScheme.surface),
      surfaceDim: applyStyle(colorScheme.surfaceDim),
      surfaceBright: applyStyle(colorScheme.surfaceBright),
      surfaceContainerLowest: applyStyle(colorScheme.surfaceContainerLowest),
      surfaceContainerLow: applyStyle(colorScheme.surfaceContainerLow),
      surfaceContainer: applyStyle(colorScheme.surfaceContainer),
      surfaceContainerHigh: applyStyle(colorScheme.surfaceContainerHigh),
      surfaceContainerHighest: applyStyle(
        colorScheme.surfaceContainerHighest,
      ),
    );
  }

  OutlineInputBorder _buildInputBorder(AppStyleTheme appStyle, Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
      borderSide: BorderSide(
        color: appStyle.useBorderlessButtons ? Colors.transparent : color,
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

  late AnimationController _logoController; // Logo 动画控制器
  late AnimationController _textController; // 文字动画控制器
  late Animation<double> _logoScale; // Logo 缩放动画
  late Animation<double> _logoOpacity; // Logo 透明度动画
  late Animation<double> _textOpacity; // 文字透明度动画
  late Animation<Offset> _textSlide; // 文字滑入动画

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
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    // 文字透明度从 0 到 1
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

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
            return FadeTransition(opacity: animation, child: child);
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
                    const Color(0xFF1a1a2e), // 深色渐变起点
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f23), // 深色渐变终点
                  ]
                : [
                    const Color(0xFFf8f9ff), // 浅色渐变起点
                    const Color(0xFFe8eeff),
                    const Color(0xFFdde4ff), // 浅色渐变终点
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
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.4),

                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset('app.png', fit: BoxFit.cover),
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
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
