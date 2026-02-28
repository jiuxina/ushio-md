import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';
import '../models/campus_user.dart';
import '../services/supabase_service.dart';

/// 认证状态提供者
///
/// 管理用户登录、登出及会话恢复。
class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  // ==================== 状态 ====================

  CampusUser? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  // ==================== Getters ====================

  CampusUser? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether Supabase credentials have been configured.
  bool get isSupabaseConfigured => SupabaseConfig.isConfigured;

  // ==================== 初始化 ====================

  /// Checks configuration and restores any existing session.
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!SupabaseConfig.isConfigured) {
        _error = '服务维护中，请稍后再试';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _supabaseService.initialize();

      final user = _supabaseService.getCurrentUser();
      if (user != null) {
        _currentUser = CampusUser.fromJson(user.userMetadata ?? {});
        _isLoggedIn = true;
      }
    } on SupabaseNotConfiguredException {
      _error = '服务维护中，请稍后再试';
    } catch (e) {
      _error = '初始化失败，请稍后再试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 登录 ====================

  /// Signs in with [studentId] and [password].
  Future<void> signIn(String studentId, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!SupabaseConfig.isConfigured) {
        _error = '服务维护中，请稍后再试';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _supabaseService.signIn(
        email: studentId,
        password: password,
      );

      if (response.user != null) {
        _currentUser = CampusUser.fromJson(
          response.user!.userMetadata ?? {},
        );
        _isLoggedIn = true;
      } else {
        _error = '登录失败，请检查账号和密码';
      }
    } on SupabaseNotConfiguredException {
      _error = '服务维护中，请稍后再试';
    } catch (e) {
      _error = '登录失败，请检查账号和密码';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 登出 ====================

  /// Signs out the current user.
  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.signOut();
      _currentUser = null;
      _isLoggedIn = false;
    } on SupabaseNotConfiguredException {
      _error = '服务维护中，请稍后再试';
    } catch (e) {
      _error = '登出失败，请稍后再试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
