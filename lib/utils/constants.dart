import 'package:flutter/material.dart';

/// App-wide constants and theme configuration
class AppConstants {
  // App info
  static const String appName = '汐';
  static const String appVersion = '1.0.0';
  static const String appDescription = '简易的 Markdown 编辑器';
  static const String appAuthor = 'jiuxina';
  static const String githubUrl = 'https://github.com/jiuxina/mdreader';

  // Colors
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accentColor = Color(0xFF22D3EE);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFF59E0B);

  // Light theme colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Padding & Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Border radius
  static const double borderRadius = 12.0;
  static const double borderRadiusSmall = 8.0;

  // Animation durations
  static const Duration animationDuration = Duration(milliseconds: 300);
}

/// Light theme
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

/// Dark theme
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
