/// Supabase configuration for 相思同行 campus app.
///
/// To configure Supabase:
/// 1. Create a project at https://supabase.com
/// 2. Go to Project Settings > API
/// 3. Copy the "Project URL" and replace [supabaseUrl] below
/// 4. Copy the "anon public" key and replace [supabaseAnonKey] below
class SupabaseConfig {
  SupabaseConfig._();

  // TODO: Replace with your Supabase project URL
  // Found at: https://supabase.com/dashboard/project/<ref>/settings/api
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';

  // TODO: Replace with your Supabase anon key
  // Found at: https://supabase.com/dashboard/project/<ref>/settings/api
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Returns `true` when both [supabaseUrl] and [supabaseAnonKey] have been
  /// replaced with real values.
  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
}
