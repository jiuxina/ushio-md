/// ============================================================================
/// 应用常量配置
/// ============================================================================
/// 
/// 集中管理应用的所有常量，包括：
/// - 应用信息
/// - 颜色配置
/// - 尺寸规范
/// - 预设主题
/// ============================================================================

import 'package:flutter/material.dart';

/// 应用常量
/// 
/// 使用静态常量确保全局一致性
class AppConstants {
  // ==================== 应用信息 ====================
  
  /// 应用名称
  static const String appName = '汐';
  
  /// 版本号
  static const String appVersion = '1.0.1';
  
  /// 应用描述
  static const String appDescription = 'Markdown 编辑器';
  
  /// 作者
  static const String appAuthor = 'jiuxina';
  
  /// GitHub 仓库地址
  static const String githubUrl = 'https://github.com/jiuxina/ushio-md';

  // ==================== 主题色 ====================
  
  /// 主色调（靛蓝）
  static const Color primaryColor = Color(0xFF6366F1);
  
  /// 主色调深色变体
  static const Color primaryDark = Color(0xFF4F46E5);
  
  /// 强调色（青色）
  static const Color accentColor = Color(0xFF22D3EE);
  
  /// 错误色（红色）
  static const Color errorColor = Color(0xFFEF4444);
  
  /// 成功色（绿色）
  static const Color successColor = Color(0xFF22C55E);
  
  /// 警告色（琥珀色）
  static const Color warningColor = Color(0xFFF59E0B);

  // ==================== 浅色主题色 ====================
  
  /// 浅色背景
  static const Color lightBackground = Color(0xFFF8FAFC);
  
  /// 浅色表面
  static const Color lightSurface = Color(0xFFFFFFFF);
  
  /// 浅色主文字
  static const Color lightText = Color(0xFF1E293B);
  
  /// 浅色次要文字
  static const Color lightTextSecondary = Color(0xFF64748B);

  // ==================== 深色主题色 ====================
  
  /// 深色背景
  static const Color darkBackground = Color(0xFF0F172A);
  
  /// 深色表面
  static const Color darkSurface = Color(0xFF1E293B);
  
  /// 深色主文字
  static const Color darkText = Color(0xFFF1F5F9);
  
  /// 深色次要文字
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // ==================== 尺寸规范 ====================
  
  /// 小内边距
  static const double paddingSmall = 8.0;
  
  /// 中等内边距
  static const double paddingMedium = 16.0;
  
  /// 大内边距
  static const double paddingLarge = 24.0;

  /// 标准圆角
  static const double borderRadius = 12.0;
  
  /// 小圆角
  static const double borderRadiusSmall = 8.0;

  // ==================== 动画配置 ====================
  
  /// 标准动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
}

/// ============================================================================
/// 预设主题配置
/// ============================================================================

/// 浅色主题
/// 
/// 注意：主应用使用 main.dart 中的动态主题构建，此处保留供参考
ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: AppConstants.primaryColor,
    secondary: AppConstants.accentColor,
    surface: AppConstants.lightSurface,
    error: AppConstants.errorColor,
  ),
  scaffoldBackgroundColor: AppConstants.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppConstants.lightSurface,
    foregroundColor: AppConstants.lightText,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AppConstants.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      side: BorderSide(color: Colors.grey.shade200),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppConstants.primaryColor,
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
    ),
    filled: true,
    fillColor: AppConstants.lightBackground,
  ),
  dividerTheme: DividerThemeData(
    color: Colors.grey.shade200,
    thickness: 1,
  ),
);

/// 深色主题
ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AppConstants.primaryColor,
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
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppConstants.primaryColor,
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
