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
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'l10n/app_localizations.dart';
import 'providers/file_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';
import 'services/font_service.dart';
import 'services/my_files_service.dart';
import 'utils/app_style.dart';
import 'utils/constants.dart';
import 'utils/theme_tones.dart';

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
      titleBarStyle: TitleBarStyle.hidden,
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

  // 加载已安装的自定义字体（包括远程下载的内置字体）
  await FontService.loadAllCustomFonts();

  await LiquidGlassWidgets.initialize();

  // 用平台真实版本号覆盖硬编码默认值，避免更新检查/关于页的版本漂移
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.version.isNotEmpty) {
      AppConstants.appVersion = packageInfo.version;
    }
  } catch (_) {
    // 读取失败时保留 constants.dart 中的兜底默认值
  }

  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: const MyApp(),
    ),
  );
}

/// ============================================================================
/// 主应用组件
/// ============================================================================

/// 系统栏（状态栏 + 导航栏）外观，按 App 当前主题的明暗派生。
///
/// 两条都必须是透明的，让页面渐变一直铺到屏幕边缘；图标的明暗反过来跟主题走，
/// 浅色主题配深色图标。系统夜间模式不能参与判断：用户可以只把 App 设成浅色。
SystemUiOverlayStyle overlayStyleForBrightness(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: brightness,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    // 关掉 Android 10 给透明导航栏自动叠的那层暗色遮罩，否则浅色页面底部
    // 会凭空多出一条灰带。
    systemNavigationBarContrastEnforced: false,
  );
}

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
      child: Selector<SettingsProvider, ThemeInputs>(
        selector: (_, settings) => ThemeInputs.from(settings),
        builder: (context, inputs, child) {

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
            locale: inputs.locale, // 使用动态语言设置
            // Android 系统返回不做预测性退出预览；页面间仍使用普通缩放过渡。
            onNavigationNotification: (notification) {
              SystemNavigator.setFrameworkHandlesBack(
                notification.canHandlePop,
              );
              return false;
            },
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
            theme: _buildThemeFor(Brightness.light, inputs),
            darkTheme: _buildThemeFor(Brightness.dark, inputs),
            themeMode: inputs.themeMode, // 主题模式（跟随系统/浅色/深色）
            builder: (context, child) {
              final pageChild = child ?? const SizedBox.shrink();
              // 系统栏跟随 App 自己的主题：把 App 单独设成浅色而系统仍是深色时，
              // 浅色底上必须是深色图标，否则状态栏直接看不清。
              final overlayStyle = AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyleForBrightness(Theme.of(context).brightness),
                child: pageChild,
              );

              if (!_isLiquidGlassMode()) {
                return overlayStyle;
              }

              // statusBarStyle 交给上面自己接管：GlassPage 的 auto 只认系统的
              // 夜间模式，而且它在 dispose 时会把样式还原成硬编码的白色图标。
              return GlassPage(
                settings: LiquidGlassSettings(
                  glassColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x2E101828)
                      : const Color(0x66FFFFFF),
                  blur: 16,
                  platformViewMode: PlatformViewGlassMode.passthrough,
                ),
                statusBarStyle: GlassStatusBarStyle.none,
                child: overlayStyle,
              );
            },
            home: const MainScreen(), // 主页面
          );
        },
      ),
    );
  }

  /// 构建指定明暗的主题
  ///
  /// 浅色与深色此前各有 8 个位置参数、且第 3/4 位顺序不同（配色方案索引与
  /// fontFamily 互换），是最容易传错的地方，故合并为单一入口 + 值对象。
  ThemeData _buildThemeFor(Brightness brightness, ThemeInputs inputs) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? AppConstants.darkThemeSchemes[inputs.darkThemeIndex]
        : AppConstants.lightThemeSchemes[inputs.lightThemeIndex];

    // 全部语义角色由 ThemeTones 显式产出；此前这里只给 4 个角色，
    // 其余被 Flutter 的 getter 回退链塌缩成荧光青 secondary / 满饱和 primary。
    final colorScheme = ThemeTones.scheme(
      brightness: brightness,
      primary: inputs.primaryColor,
      themeScheme: scheme,
      error: AppConstants.errorColor,
    );

    return _buildTheme(
      brightness: brightness,
      colorScheme: colorScheme,
      backgroundColor: scheme.background,
      textColor: inputs.uiFontColorFor(brightness),
      textSecondaryColor: scheme.textSecondary,
      fontFamily: inputs.fontFamily,
      buttonStyleMode: inputs.buttonStyleMode,
      cardOpacity: inputs.cardOpacity,
      customCardColor: inputs.customCardColor,
      customIconColor: inputs.customIconColor,
    );
  }

  /// 判断是否处于液态玻璃模式。
  static bool _isLiquidGlassMode() {
    final context = WidgetsBinding.instance.rootElement;
    if (context == null) return false;
    final appStyle = Theme.of(context).extension<AppStyleTheme>();
    return appStyle?.useLiquidGlass ?? false;
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
    Color? customIconColor,
  }) {
    // 角色已全部显式赋值，这里只负责卡片透明度。
    // 原先的 `!= 0xFF000000` 兜底判断在深色模式下从不生效：
    // 塌缩后 outline 是纯白、secondaryContainer 是荧光青，都不等于黑。
    final effectiveColorScheme = _applyGlobalCardOpacity(
      colorScheme,
      cardOpacity,
      customCardColor: customCardColor,
    );
    final appStyle = AppStyleTheme.resolve(
      brightness: brightness,
      colorScheme: effectiveColorScheme,
      backgroundColor: backgroundColor,
      textSecondary: textSecondaryColor,
      buttonStyleMode: buttonStyleMode,
      cardOpacity: cardOpacity,
      customCardColor: customCardColor,
      customIconColor: customIconColor,
    );

    final buttonForeground = appStyle.useBorderlessButtons
        ? textColor
        : effectiveColorScheme.onPrimary;
    final buttonBackground = appStyle.useBorderlessButtons
        ? appStyle.strongSurface
        : effectiveColorScheme.primary.withValues(alpha: appStyle.cardOpacity);
    final isGlass = appStyle.useLiquidGlass;
    Widget glassButtonBackground({
      required BorderRadius borderRadius,
      required Widget? child,
    }) {
      return GlassContainer(
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius.topLeft.x),
        child: child,
      );
    }

    final pageTransitionsTheme = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
      },
    );

    ThemeData theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: effectiveColorScheme,
      pageTransitionsTheme: pageTransitionsTheme,
      iconTheme: IconThemeData(color: appStyle.iconColor),
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
        // 二级页的 AppBar 背景是透明的，Material 会按背景亮度自己推断状态栏
        // 图标颜色，透明色被判成深色 → 浅色主题下图标跟着变白。显式给一个。
        systemOverlayStyle: overlayStyleForBrightness(brightness),
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
              foregroundColor: isGlass ? textColor : buttonForeground,
              backgroundColor: isGlass ? Colors.transparent : buttonBackground,
              disabledBackgroundColor: isGlass
                  ? Colors.transparent
                  : buttonBackground.withValues(alpha: 0.45),
              disabledForegroundColor: isGlass
                  ? textColor.withValues(alpha: 0.45)
                  : buttonForeground.withValues(alpha: 0.55),
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
              backgroundBuilder: isGlass
                  ? (context, states, child) => glassButtonBackground(
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    )
                  : null,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
              foregroundColor: appStyle.useBorderlessButtons
                  ? textColor
                  : isGlass
                  ? textColor
                  : colorScheme.primary,
              backgroundColor: isGlass
                  ? Colors.transparent
                  : appStyle.useBorderlessButtons
                  ? appStyle.strongSurface
                  : Colors.transparent,
              side: BorderSide(
                color: appStyle.useBorderlessButtons && !isGlass
                    ? Colors.transparent
                    : appStyle.outlineColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colorScheme.primary.withValues(alpha: 0.08),
              ),
              backgroundBuilder: isGlass
                  ? (context, states, child) => glassButtonBackground(
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    )
                  : null,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
              foregroundColor: isGlass ? textColor : buttonForeground,
              backgroundColor: isGlass ? Colors.transparent : buttonBackground,
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
              backgroundBuilder: isGlass
                  ? (context, states, child) => glassButtonBackground(
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    )
                  : null,
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
              foregroundColor: appStyle.useBorderlessButtons
                  ? textColor
                  : isGlass
                  ? textColor
                  : colorScheme.primary,
              backgroundColor:
                  appStyle.useBorderlessButtons
                  ? appStyle.strongSurface
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colorScheme.primary.withValues(alpha: 0.08),
              ),
              backgroundBuilder: isGlass
                  ? (context, states, child) => glassButtonBackground(
                      borderRadius: BorderRadius.circular(14),
                      child: child,
                    )
                  : null,
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
              foregroundColor: appStyle.iconColor,
              backgroundColor:
                  appStyle.useBorderlessButtons
                  ? appStyle.strongSurface
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colorScheme.primary.withValues(alpha: 0.08),
              ),
              backgroundBuilder: isGlass
                  ? (context, states, child) => glassButtonBackground(
                      borderRadius: BorderRadius.circular(14),
                      child: child,
                    )
                  : null,
            ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isGlass
            ? Colors.transparent
            : appStyle.useBorderlessButtons
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: appStyle.scaledSurfaceColor(
          effectiveColorScheme,
          alpha: 0.95,
        ),
        contentTextStyle: TextStyle(color: textColor),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: appStyle.iconColor,
        textColor: textColor,
        subtitleTextStyle: TextStyle(color: textSecondaryColor),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isGlass
              ? appStyle.strongSurface
              : effectiveColorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: isGlass ? textColor : effectiveColorScheme.onInverseSurface,
          fontSize: 12,
        ),
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
  }) {
    // 自定义卡片色非空即覆盖主题表面色
    Color applyStyle(Color originalColor) {
      final baseColor = customCardColor ?? originalColor;
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
      surfaceContainerHighest: applyStyle(colorScheme.surfaceContainerHighest),
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

/// 构建主题所需的全部设置；值对象以便 Selector 精确收敛重建粒度。
///
/// MaterialApp 此前被 Consumer 整体包住，任意 notifyListeners（含调试日志追加）
/// 都会重建两套 ThemeData。改用 `Selector<SettingsProvider, ThemeInputs>` 后只有
/// 这里列出的字段变化才会重绘主题——因此新增主题相关设置时必须同步加字段，
/// 否则该设置会静默失效；test/main/theme_inputs_contract_test.dart 负责钉住这点。
@immutable
class ThemeInputs {
  const ThemeInputs({
    required this.primaryColor,
    required this.uiFontColorLight,
    required this.uiFontColorDark,
    required this.fontFamily,
    required this.lightThemeIndex,
    required this.darkThemeIndex,
    required this.buttonStyleMode,
    required this.cardOpacity,
    required this.customCardColor,
    required this.customIconColor,
    required this.themeMode,
    required this.locale,
  });

  factory ThemeInputs.from(SettingsProvider settings) => ThemeInputs(
    primaryColor: settings.primaryColor,
    uiFontColorLight: settings.uiFontColorFor(Brightness.light),
    uiFontColorDark: settings.uiFontColorFor(Brightness.dark),
    fontFamily: settings.uiFontFamily == 'System'
        ? null
        : settings.uiFontFamily,
    lightThemeIndex: settings.lightThemeIndex,
    darkThemeIndex: settings.darkThemeIndex,
    buttonStyleMode: settings.buttonStyleMode,
    cardOpacity: settings.cardOpacity,
    customCardColor: settings.customCardColor,
    customIconColor: settings.customIconColor,
    themeMode: settings.themeMode,
    locale: settings.locale,
  );

  final Color primaryColor;
  final Color uiFontColorLight;
  final Color uiFontColorDark;
  final String? fontFamily;
  final int lightThemeIndex;
  final int darkThemeIndex;
  final AppButtonStyleMode buttonStyleMode;
  final double cardOpacity;
  final Color? customCardColor;
  final Color? customIconColor;
  final ThemeMode themeMode;
  final Locale locale;

  Color uiFontColorFor(Brightness brightness) =>
      brightness == Brightness.dark ? uiFontColorDark : uiFontColorLight;

  @override
  bool operator ==(Object other) =>
      other is ThemeInputs &&
      other.primaryColor == primaryColor &&
      other.uiFontColorLight == uiFontColorLight &&
      other.uiFontColorDark == uiFontColorDark &&
      other.fontFamily == fontFamily &&
      other.lightThemeIndex == lightThemeIndex &&
      other.darkThemeIndex == darkThemeIndex &&
      other.buttonStyleMode == buttonStyleMode &&
      other.cardOpacity == cardOpacity &&
      other.customCardColor == customCardColor &&
      other.customIconColor == customIconColor &&
      other.themeMode == themeMode &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(
    primaryColor,
    uiFontColorLight,
    uiFontColorDark,
    fontFamily,
    lightThemeIndex,
    darkThemeIndex,
    buttonStyleMode,
    cardOpacity,
    customCardColor,
    customIconColor,
    themeMode,
    locale,
  );
}
