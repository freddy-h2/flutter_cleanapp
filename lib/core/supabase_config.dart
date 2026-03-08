import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes the Supabase client using credentials from .env.local.
abstract final class SupabaseConfig {
  /// Call this once in main() before runApp().
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env.local');
    final url = dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!;
    final anonKey = dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY']!;
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Convenience accessor for the Supabase client.
  static SupabaseClient get client => Supabase.instance.client;
}
