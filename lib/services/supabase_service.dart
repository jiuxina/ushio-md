import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Exception thrown when Supabase has not been configured.
class SupabaseNotConfiguredException implements Exception {
  @override
  String toString() =>
      'Supabase is not configured. '
      'Please set supabaseUrl and supabaseAnonKey in '
      'lib/config/supabase_config.dart';
}

/// Singleton service that wraps the Supabase client for the 相思同行 campus app.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService _instance = SupabaseService._();

  /// Returns the shared [SupabaseService] instance.
  static SupabaseService get instance => _instance;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes Supabase.
  ///
  /// If Supabase is not configured (placeholder credentials), this method
  /// returns without error so the app can still start in offline /
  /// maintenance mode. Subsequent calls to data or auth methods will throw
  /// [SupabaseNotConfiguredException].
  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }
    if (_initialized) {
      return;
    }
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  /// The underlying [SupabaseClient].
  ///
  /// Throws [SupabaseNotConfiguredException] if Supabase is not configured.
  SupabaseClient get client {
    _ensureConfigured();
    return Supabase.instance.client;
  }

  // ---------------------------------------------------------------------------
  // Connection status
  // ---------------------------------------------------------------------------

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Whether the Supabase project credentials have been provided.
  bool get isConfigured => SupabaseConfig.isConfigured;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Signs in a student with [email] and [password].
  ///
  /// The campus authentication system uses the student's email address
  /// (e.g. `studentId@university.edu`) as the login identifier.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    return client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    _ensureConfigured();
    await client.auth.signOut();
  }

  /// Returns the currently authenticated [User], or `null` if not signed in.
  User? getCurrentUser() {
    _ensureConfigured();
    return client.auth.currentUser;
  }

  // ---------------------------------------------------------------------------
  // Data – Announcements
  // ---------------------------------------------------------------------------

  /// Fetches all rows from the `announcements` table, ordered by `created_at`
  /// descending.
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    _ensureConfigured();
    final response = await client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Data – Courses
  // ---------------------------------------------------------------------------

  /// Fetches all rows from the `courses` table.
  Future<List<Map<String, dynamic>>> getCourses() async {
    _ensureConfigured();
    final response = await client.from('courses').select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches courses for a specific [userId].
  Future<List<Map<String, dynamic>>> getCoursesForUser(String userId) async {
    _ensureConfigured();
    final response = await client
        .from('courses')
        .select()
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Data – Leave Requests
  // ---------------------------------------------------------------------------

  /// Fetches leave requests for a specific [userId].
  Future<List<Map<String, dynamic>>> getLeaveRequests(String userId) async {
    _ensureConfigured();
    final response = await client
        .from('leave_requests')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Creates a new leave request.
  Future<Map<String, dynamic>> createLeaveRequest(
    Map<String, dynamic> data,
  ) async {
    _ensureConfigured();
    final response = await client
        .from('leave_requests')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Data – Venues
  // ---------------------------------------------------------------------------

  /// Fetches all rows from the `venues` table.
  Future<List<Map<String, dynamic>>> getVenues() async {
    _ensureConfigured();
    final response = await client.from('venues').select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches venues that are currently available.
  Future<List<Map<String, dynamic>>> getAvailableVenues() async {
    _ensureConfigured();
    final response = await client
        .from('venues')
        .select()
        .eq('is_available', true);
    return List<Map<String, dynamic>>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Data – Community Posts
  // ---------------------------------------------------------------------------

  /// Fetches community posts, ordered by `created_at` descending.
  Future<List<Map<String, dynamic>>> getCommunityPosts() async {
    _ensureConfigured();
    final response = await client
        .from('community_posts')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Creates a new community post.
  Future<Map<String, dynamic>> createCommunityPost(
    Map<String, dynamic> data,
  ) async {
    _ensureConfigured();
    final response = await client
        .from('community_posts')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Throws [SupabaseNotConfiguredException] when credentials are missing.
  void _ensureConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw SupabaseNotConfiguredException();
    }
  }
}
