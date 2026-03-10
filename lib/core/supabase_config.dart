import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keys for caching Supabase credentials in [SharedPreferences].
///
/// Needed because the background isolate (WorkManager) cannot access the
/// Flutter asset bundle, so [dotenv.load] fails there.
abstract final class _PrefKeys {
  static const String supabaseUrl = 'supabase_url';
  static const String supabaseAnonKey = 'supabase_anon_key';
}

/// Initializes the Supabase client using credentials from .env.local.
abstract final class SupabaseConfig {
  /// Call this once in main() before runApp().
  ///
  /// Loads credentials from [dotenv] and caches them in [SharedPreferences]
  /// so that [initializeForBackground] can read them without the asset bundle.
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env.local');
    final url = dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!;
    final anonKey = dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY']!;

    // Cache credentials for background isolate use.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.supabaseUrl, url);
    await prefs.setString(_PrefKeys.supabaseAnonKey, anonKey);

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Initializes Supabase in a background isolate using cached credentials.
  ///
  /// Unlike [initialize], this does NOT call [dotenv.load] — it reads from
  /// [SharedPreferences] which were persisted during the last foreground
  /// [initialize] call. Returns `false` if credentials are not cached yet
  /// (e.g. the app was never opened after install).
  static Future<bool> initializeForBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_PrefKeys.supabaseUrl);
    final anonKey = prefs.getString(_PrefKeys.supabaseAnonKey);

    if (url == null || anonKey == null) return false;

    await Supabase.initialize(url: url, anonKey: anonKey);
    return true;
  }

  /// Convenience accessor for the Supabase client.
  static SupabaseClient get client => Supabase.instance.client;
}
