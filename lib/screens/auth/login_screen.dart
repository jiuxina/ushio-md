import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../main_screen.dart';

/// 登录页面
///
/// 支持学号密码登录和验证码登录两种方式，
/// 使用玻璃态卡片与渐变背景，遵循 Material 3 设计规范。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ==================== 控制器 ====================

  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  // ==================== 状态 ====================

  bool _obscurePassword = true;
  bool _isCodeLogin = false;
  bool _agreedToTerms = false;
  bool _shakeCheckbox = false;

  // ==================== 动画 ====================

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _slideController;
  late final List<Animation<Offset>> _slideAnimations;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // 抖动参数
  static const double _shakeFrequency = 3;
  static const double _shakeAmplitude = 8;

  // 倒计时
  Timer? _codeTimer;
  int _codeCountdown = 0;

  @override
  void initState() {
    super.initState();

    // 整体淡入
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // 表单元素依次上滑（logo, 输入框1, 输入框2, 协议, 按钮）
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimations = List.generate(5, (i) {
      final start = i * 0.12;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    // 抖动动画（用于未勾选协议提示）
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
        setState(() => _shakeCheckbox = false);
      }
    });

    // 启动入场动画
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  // ==================== 业务逻辑 ====================

  bool get _canLogin {
    if (!_agreedToTerms) return false;
    if (_isCodeLogin) {
      return _phoneController.text.trim().length == 11 &&
          _codeController.text.trim().length == 6;
    }
    return _studentIdController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  Future<void> _handleLogin() async {
    if (!_agreedToTerms) {
      setState(() => _shakeCheckbox = true);
      _shakeController.forward();
      return;
    }
    if (!_canLogin) return;

    final authProvider = context.read<AuthProvider>();

    if (_isCodeLogin) {
      // 验证码登录暂未接入后端，提示用户
      _showSnackBar('验证码登录即将上线，请使用学号密码登录');
      return;
    }

    await authProvider.signIn(
      _studentIdController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (authProvider.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else if (authProvider.error != null) {
      _showSnackBar(authProvider.error!);
    }
  }

  void _startCodeCountdown() {
    if (_codeCountdown > 0) return;
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showSnackBar('请输入正确的手机号');
      return;
    }
    setState(() => _codeCountdown = 60);
    _codeTimer?.cancel();
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_codeCountdown <= 1) {
        timer.cancel();
        setState(() => _codeCountdown = 0);
      } else {
        setState(() => _codeCountdown--);
      }
    });
    _showSnackBar('验证码已发送');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f0f23),
                  ]
                : const [
                    Color(0xFFf8f9ff),
                    Color(0xFFf0f4ff),
                    Color(0xFFe8eeff),
                  ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      _buildLogo(),
                      const SizedBox(height: 36),
                      _buildFormCard(isDark, authProvider),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Logo 与应用名
  Widget _buildLogo() {
    return SlideTransition(
      position: _slideAnimations[0],
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.primaryColor,
                  AppConstants.accentColor,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '相思同行',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '广西民族大学智慧校园',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  /// 玻璃态表单卡片
  Widget _buildFormCard(bool isDark, AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: isDark ? 0.6 : 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            // 登录方式切换
            _buildLoginModeToggle(),
            const SizedBox(height: 24),

            // 输入区域
            if (_isCodeLogin) ...[
              SlideTransition(
                position: _slideAnimations[1],
                child: _buildPhoneField(),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimations[2],
                child: _buildCodeField(),
              ),
            ] else ...[
              SlideTransition(
                position: _slideAnimations[1],
                child: _buildStudentIdField(),
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _slideAnimations[2],
                child: _buildPasswordField(),
              ),
            ],

            const SizedBox(height: 20),

            // 用户协议
            SlideTransition(
              position: _slideAnimations[3],
              child: _buildAgreementRow(),
            ),

            const SizedBox(height: 20),

            // 错误提示
            if (authProvider.error != null) ...[
              _buildErrorBanner(authProvider.error!),
              const SizedBox(height: 16),
            ],

            // 登录按钮
            SlideTransition(
              position: _slideAnimations[4],
              child: _buildLoginButton(authProvider),
            ),
          ],
        ),
      ),
    );
  }

  /// 登录方式切换标签
  Widget _buildLoginModeToggle() {
    return Row(
      children: [
        _buildToggleTab('密码登录', !_isCodeLogin, () {
          setState(() => _isCodeLogin = false);
        }),
        const SizedBox(width: 24),
        _buildToggleTab('验证码登录', _isCodeLogin, () {
          setState(() => _isCodeLogin = true);
        }),
      ],
    );
  }

  Widget _buildToggleTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: AppConstants.animationDuration,
            height: 3,
            width: active ? 24 : 0,
            decoration: BoxDecoration(
              color: AppConstants.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// 学号/工号输入框
  Widget _buildStudentIdField() {
    return TextField(
      controller: _studentIdController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: '学号/工号',
        hintText: '请输入学号或工号',
        prefixIcon: const Icon(Icons.person_outline_rounded),
        suffixIcon: _studentIdController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () {
                  _studentIdController.clear();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  /// 密码输入框
  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: '密码',
        hintText: '请输入密码',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  /// 手机号输入框
  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: '手机号',
        hintText: '请输入绑定的手机号',
        prefixIcon: const Icon(Icons.phone_android_rounded),
        suffixIcon: _phoneController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () {
                  _phoneController.clear();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  /// 验证码输入框
  Widget _buildCodeField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '验证码',
              hintText: '6位验证码',
              prefixIcon: const Icon(Icons.shield_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _codeCountdown > 0 ? null : _startCodeCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppConstants.primaryColor.withValues(alpha: 0.4),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
            ),
            child: Text(
              _codeCountdown > 0 ? '${_codeCountdown}s' : '获取验证码',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  /// 用户协议勾选行
  Widget _buildAgreementRow() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shakeOffset = _shakeCheckbox
            ? sin(_shakeAnimation.value * _shakeFrequency * pi) * _shakeAmplitude
            : 0.0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              child: Text.rich(
                TextSpan(
                  text: '我已阅读并同意',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        height: 1.5,
                      ),
                  children: [
                    TextSpan(
                      text: '《用户协议》',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const TextSpan(text: '和'),
                    TextSpan(
                      text: '《隐私政策》',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误/维护提示条
  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppConstants.errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppConstants.errorColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 登录按钮
  Widget _buildLoginButton(AuthProvider authProvider) {
    final isLoading = authProvider.isLoading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                if (!_agreedToTerms) {
                  setState(() => _shakeCheckbox = true);
                  _shakeController.forward();
                  _showSnackBar('请先阅读并同意用户协议');
                  return;
                }
                if (_canLogin) _handleLogin();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppConstants.primaryColor.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                '登  录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
}
