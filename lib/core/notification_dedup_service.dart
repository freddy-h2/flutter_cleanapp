import 'package:shared_preferences/shared_preferences.dart';

/// Prevents duplicate notifications from being shown when the same event
/// is received via multiple channels (FCM push, Supabase Realtime, Workmanager poll).
///
/// Uses SharedPreferences to track recently shown notification event keys.
/// Keys expire after [_ttlMinutes] to avoid unbounded growth.
class NotificationDedupService {
  NotificationDedupService._();

  /// The singleton instance.
  static final NotificationDedupService instance = NotificationDedupService._();

  static const String _prefKey = 'notification_dedup_keys';
  static const int _ttlMinutes = 30;

  /// Check if an event has already been notified. If not, marks it as notified
  /// and returns true (meaning: proceed to show the notification).
  /// If already notified, returns false (meaning: skip, it is a duplicate).
  ///
  /// [eventKey] should be a unique string per event, e.g.:
  /// - `'announcement:<id>'`
  /// - `'extension_request:<id>:pending'`
  /// - `'extension_request:<id>:accepted'`
  /// - `'comment:<id>'`
  Future<bool> shouldNotify(String eventKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(_prefKey) ?? [];

      // Parse entries: each is "key|timestamp_millis"
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoff = now - (_ttlMinutes * 60 * 1000);

      // Filter out expired entries and check for duplicate
      final validEntries = <String>[];
      bool isDuplicate = false;

      for (final entry in entries) {
        final parts = entry.split('|');
        if (parts.length != 2) continue;
        final timestamp = int.tryParse(parts[1]);
        if (timestamp == null || timestamp < cutoff) continue;
        validEntries.add(entry);
        if (parts[0] == eventKey) isDuplicate = true;
      }

      if (isDuplicate) return false;

      // Add new entry
      validEntries.add('$eventKey|$now');
      await prefs.setStringList(_prefKey, validEntries);
      return true;
    } catch (_) {
      // If dedup check throws, show the notification anyway.
      return true;
    }
  }

  /// Clear all dedup entries (e.g., on logout).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
