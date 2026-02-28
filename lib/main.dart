// ============================================================================
// 相思同行 - 广西民族大学智慧校园
// ============================================================================
// 
// 一款面向广西民族大学师生的智慧校园服务应用。
// 
// 功能特性：
// - 🏠 校园首页看板（天气、课表、校车、公告）
// - 📚 学业中心（成绩、课表、证明）
// - 📋 智慧办事（请假、报修、审批）
// - 🤝 社区与场馆（校园圈、场馆预约、心理健康）
// - 👤 个人中心（身份、缴费、设置）
// 
// 技术栈：
// - Flutter - 跨平台 UI 框架
// - Provider - 状态管理
// - Supabase - 后端数据库与认证
// 
// @author jiuxina
// @version 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/campus_provider.dart';
import 'providers/teacher_provider.dart';
import 'providers/ai_provider.dart';
import 'config/supabase_config.dart';
import 'services/supabase_service.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'utils/constants.dart';

/// ============================================================================
/// 应用入口
/// ============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 尝试初始化 Supabase（如果已配置）
  if (SupabaseConfig.isConfigured) {
    try {
      await SupabaseService.instance.initialize();
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }
  
  runApp(const MyApp());
}

/// ============================================================================
/// 主应用组件
/// ============================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CampusProvider()),
        ChangeNotifierProvider(create: (_) => TeacherProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          Color primaryColor = settings.primaryColor;
          final fontFamily = settings.uiFontFamily == 'System' ? null : settings.uiFontFamily;
          final darkThemeIndex = settings.darkThemeIndex;
          final lightThemeIndex = settings.lightThemeIndex;
          
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            locale: settings.locale,
            theme: _buildLightTheme(primaryColor, fontFamily, lightThemeIndex),
            darkTheme: _buildDarkTheme(primaryColor, darkThemeIndex, fontFamily),
            themeMode: settings.themeMode,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/main': (context) => const MainScreen(),
            },
            home: const _AppEntry(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme(Color primaryColor, String? fontFamily, int lightThemeIndex) {
    final scheme = AppConstants.lightThemeSchemes[lightThemeIndex];
    
    var colorScheme = ColorScheme.light(
      primary: primaryColor,
      secondary: AppConstants.accentColor,
      surface: scheme.surface,
      error: AppConstants.errorColor,
    );
    
    ThemeData theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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
          side: BorderSide(color: scheme.textSecondary.withValues(alpha: 0.2)),
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
        color: scheme.textSecondary.withValues(alpha: 0.2),
        thickness: 1,
      ),
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
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
    );
    
    if (fontFamily != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: fontFamily),
      );
    }
    
    return theme;
  }

  ThemeData _buildDarkTheme(Color primaryColor, int darkThemeIndex, String? fontFamily) {
    final scheme = AppConstants.darkThemeSchemes[darkThemeIndex];
    
    var colorScheme = ColorScheme.dark(
      primary: primaryColor,
      secondary: AppConstants.accentColor,
      surface: scheme.surface,
      error: AppConstants.errorColor,
    );
    
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
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: scheme.text),
        bodyMedium: TextStyle(color: scheme.text),
        bodySmall: TextStyle(color: scheme.textSecondary),
        titleLarge: TextStyle(color: scheme.text),
        titleMedium: TextStyle(color: scheme.text),
        titleSmall: TextStyle(color: scheme.textSecondary),
      ),
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
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
    );
    
    if (fontFamily != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: fontFamily),
      );
    }
    
    return theme;
  }
}

/// 应用入口 - 根据登录状态决定显示登录页还是主页
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authProvider = context.read<AuthProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    
    await settingsProvider.initialize();
    await authProvider.initialize();
    
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return _buildSplash(context);
    }
    
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoggedIn) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }

  Widget _buildSplash(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f23),
                  ]
                : [
                    const Color(0xFFf8f9ff),
                    const Color(0xFFe8eeff),
                    const Color(0xFFdde4ff),
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.asset('app.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


