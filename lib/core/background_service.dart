import 'package:flutter/foundation.dart';
import 'package:flutter_cleanapp/core/notification_service.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Keys for SharedPreferences used by the background task.
abstract final class _PrefKeys {
  static const String lastKnownPendingExtensionIds =
      'bg_known_pending_extension_ids';
  static const String lastKnownAcceptedExtensionIds =
      'bg_known_accepted_extension_ids';
  static const String lastKnownRejectedExtensionIds =
      'bg_known_rejected_extension_ids';
  static const String lastKnownAnnouncementIds = 'bg_known_announcement_ids';
  static const String lastKnownCommentCount = 'bg_last_comment_count';
  static const String currentUserId = 'bg_current_user_id';
  static const String currentScheduleId = 'bg_current_schedule_id';
}

/// Unique task name for the periodic background check.
const String backgroundTaskName = 'com.limpy.backgroundCheck';

/// Top-level callback for [Workmanager]. Runs in its own isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await _performBackgroundCheck();
      return true;
    } catch (e) {
      debugPrint('BackgroundService: error — $e');
      return false;
    }
  });
}

/// Performs the actual background data check and fires notifications.
Future<void> _performBackgroundCheck() async {
  // Initialize services needed in the background isolate.
  // Use initializeForBackground() which reads cached credentials from
  // SharedPreferences instead of dotenv (asset bundle is unavailable here).
  final initialized = await SupabaseConfig.initializeForBackground();
  if (!initialized) return;
  await NotificationService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString(_PrefKeys.currentUserId);
  if (userId == null) return;

  final client = SupabaseConfig.client;

  // ── Check for new extension requests targeting this user ────────────────
  final pendingData = await client
      .from('extension_requests')
      .select()
      .eq('next_user_id', userId)
      .eq('status', 'pending');

  final knownPendingIds =
      prefs.getStringList(_PrefKeys.lastKnownPendingExtensionIds)?.toSet() ??
      {};
  final currentPendingIds = (pendingData as List)
      .map((r) => r['id'] as String)
      .toSet();
  final newPendingIds = currentPendingIds.difference(knownPendingIds);

  for (final id in newPendingIds) {
    final request = pendingData.firstWhere((r) => r['id'] == id);
    final requesterId = request['requester_id'] as String;
    // Try to get requester name.
    final profile = await client
        .from('profiles')
        .select('name')
        .eq('id', requesterId)
        .maybeSingle();
    final name = (profile?['name'] as String?) ?? 'Un vecino';
    await NotificationService.instance.notifyProrrogaReceived(
      requesterName: name,
    );
  }
  await prefs.setStringList(
    _PrefKeys.lastKnownPendingExtensionIds,
    currentPendingIds.toList(),
  );

  // ── Check for accepted/rejected own requests ───────────────────────────
  final ownResolvedData = await client
      .from('extension_requests')
      .select()
      .eq('requester_id', userId)
      .neq('status', 'pending');

  final knownAcceptedIds =
      prefs.getStringList(_PrefKeys.lastKnownAcceptedExtensionIds)?.toSet() ??
      {};
  final knownRejectedIds =
      prefs.getStringList(_PrefKeys.lastKnownRejectedExtensionIds)?.toSet() ??
      {};

  final currentAcceptedIds = (ownResolvedData as List)
      .where((r) => r['status'] == 'accepted')
      .map((r) => r['id'] as String)
      .toSet();
  final currentRejectedIds = ownResolvedData
      .where((r) => r['status'] == 'rejected')
      .map((r) => r['id'] as String)
      .toSet();

  final newAccepted = currentAcceptedIds.difference(knownAcceptedIds);
  final newRejected = currentRejectedIds.difference(knownRejectedIds);

  if (newAccepted.isNotEmpty) {
    await NotificationService.instance.notifyProrrogaAccepted();
  }
  if (newRejected.isNotEmpty) {
    await NotificationService.instance.notifyProrrogaRejected();
  }

  await prefs.setStringList(
    _PrefKeys.lastKnownAcceptedExtensionIds,
    currentAcceptedIds.toList(),
  );
  await prefs.setStringList(
    _PrefKeys.lastKnownRejectedExtensionIds,
    currentRejectedIds.toList(),
  );

  // ── Check for new announcements ────────────────────────────────────────
  final announcementsData = await client
      .from('announcements')
      .select()
      .eq('is_active', true);

  final knownAnnouncementIds =
      prefs.getStringList(_PrefKeys.lastKnownAnnouncementIds)?.toSet() ?? {};
  final currentAnnouncementIds = (announcementsData as List)
      .map((a) => a['id'] as String)
      .toSet();
  final newAnnouncementIds = currentAnnouncementIds.difference(
    knownAnnouncementIds,
  );

  for (final id in newAnnouncementIds) {
    final announcement = announcementsData.firstWhere((a) => a['id'] == id);
    await NotificationService.instance.notifyAnnouncement(
      title: announcement['title'] as String? ?? 'Anuncio',
      body: announcement['message'] as String? ?? '',
    );
  }
  await prefs.setStringList(
    _PrefKeys.lastKnownAnnouncementIds,
    currentAnnouncementIds.toList(),
  );

  // ── Check for new comments (if user is responsible) ────────────────────
  final scheduleId = prefs.getString(_PrefKeys.currentScheduleId);
  if (scheduleId != null) {
    final commentsData = await client
        .from('comments')
        .select()
        .eq('schedule_id', scheduleId)
        .isFilter('parent_id', null);
    final currentCount = (commentsData as List).length;
    final lastCount = prefs.getInt(_PrefKeys.lastKnownCommentCount) ?? 0;

    if (lastCount > 0 && currentCount > lastCount) {
      final newCount = currentCount - lastCount;
      for (var i = 0; i < newCount; i++) {
        await NotificationService.instance.notifyNewComment(
          commentIndex: lastCount + i,
        );
      }
    }
    await prefs.setInt(_PrefKeys.lastKnownCommentCount, currentCount);
  }

  // Clean up old completed schedules
  try {
    await SupabaseService.instance.cleanupOldSchedules();
  } catch (_) {
    // Non-fatal — cleanup will retry on next periodic check
  }
}

/// Manages background notification polling via [Workmanager].
class BackgroundService {
  BackgroundService._();

  /// The singleton instance.
  static final BackgroundService instance = BackgroundService._();

  /// Initializes the Workmanager plugin. Call once in [main].
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Starts the periodic background check task.
  ///
  /// Runs approximately every 15 minutes (minimum interval allowed by
  /// Android's WorkManager).
  Future<void> startPeriodicCheck() async {
    await Workmanager().registerPeriodicTask(
      backgroundTaskName,
      backgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Stops the periodic background check task.
  Future<void> stopPeriodicCheck() async {
    await Workmanager().cancelByUniqueName(backgroundTaskName);
  }

  /// Persists the current user ID and schedule ID so the background task
  /// knows which user to check for.
  Future<void> updateUserContext({
    required String userId,
    String? scheduleId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefKeys.currentUserId, userId);
    if (scheduleId != null) {
      await prefs.setString(_PrefKeys.currentScheduleId, scheduleId);
    } else {
      await prefs.remove(_PrefKeys.currentScheduleId);
    }
  }

  /// Clears persisted user context (e.g., on logout).
  Future<void> clearUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefKeys.currentUserId);
    await prefs.remove(_PrefKeys.currentScheduleId);
  }
}
