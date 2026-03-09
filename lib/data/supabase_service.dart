import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Singleton service that wraps all Supabase database operations.
///
/// Use [SupabaseService.instance] to access the shared instance.
class SupabaseService {
  SupabaseService._();

  /// The shared singleton instance.
  static final SupabaseService instance = SupabaseService._();

  // --- Auth helpers ---

  /// Current authenticated user profile, or null if not signed in.
  ///
  /// Uses [maybeSingle] so it returns null instead of throwing when no profile
  /// row exists yet. If the profile is missing but the auth user is present,
  /// retries up to 3 times with a 1-second delay to handle signup-trigger lag.
  Future<UserModel?> getCurrentUser() async {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser == null) return null;

    const maxRetries = 3;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      if (data != null) {
        return UserModel.fromJson(data);
      }
      // Profile row not yet created (signup trigger may still be running).
      // Wait 1 second before retrying, unless this was the last attempt.
      if (attempt < maxRetries - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  // --- Profiles ---

  /// Updates the current user's profile name and/or room.
  Future<void> updateProfile({String? name, String? room}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (room != null) updates['room'] = room;
    if (updates.isEmpty) return;
    await SupabaseConfig.client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }

  /// Returns all user profiles ordered by name.
  Future<List<UserModel>> getUsers() async {
    final data = await SupabaseConfig.client
        .from('profiles')
        .select()
        .order('name');
    return data.map((json) => UserModel.fromJson(json)).toList();
  }

  /// Updates the role of the user with [userId].
  Future<void> updateUserRole(String userId, UserRole role) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({'role': role == UserRole.admin ? 'admin' : 'user'})
        .eq('id', userId);
  }

  /// Deletes the profile with [userId].
  ///
  /// Cascade rules in the database handle related schedules.
  Future<void> deleteUser(String userId) async {
    await SupabaseConfig.client.from('profiles').delete().eq('id', userId);
  }

  // --- Schedules ---

  /// Number of days in a cleaning period.
  static const int cleaningPeriodDays = 3;

  /// Returns all cleaning schedules ordered by date.
  Future<List<CleaningSchedule>> getSchedules() async {
    final data = await SupabaseConfig.client
        .from('schedules')
        .select()
        .order('date');
    return data.map((json) => CleaningSchedule.fromJson(json)).toList();
  }

  /// Returns schedules within the current 3-day cleaning period window.
  ///
  /// A schedule is considered "current" if its date falls within the window
  /// [today - (cleaningPeriodDays - 1), today].
  Future<List<CleaningSchedule>> getCurrentPeriodSchedules() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = today.subtract(Duration(days: cleaningPeriodDays - 1));
    final tomorrow = today.add(const Duration(days: 1));
    final data = await SupabaseConfig.client
        .from('schedules')
        .select()
        .gte('date', periodStart.toIso8601String().split('T').first)
        .lt('date', tomorrow.toIso8601String().split('T').first)
        .order('date');
    return data.map((json) => CleaningSchedule.fromJson(json)).toList();
  }

  /// Returns the schedule for the current calendar week, or null if none.
  ///
  /// Deprecated: prefer [getCurrentPeriodSchedules] for 3-day period logic.
  Future<CleaningSchedule?> getCurrentWeekSchedule() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final data = await SupabaseConfig.client
        .from('schedules')
        .select()
        .gte('date', weekStart.toIso8601String().split('T').first)
        .lt('date', weekEnd.toIso8601String().split('T').first)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return CleaningSchedule.fromJson(data);
  }

  /// Inserts a new cleaning schedule.
  Future<void> createSchedule(CleaningSchedule schedule) async {
    await SupabaseConfig.client.from('schedules').insert(schedule.toJson());
  }

  /// Inserts multiple cleaning schedules in a single batch operation.
  Future<void> createSchedulesBatch(List<CleaningSchedule> schedules) async {
    await SupabaseConfig.client
        .from('schedules')
        .insert(schedules.map((s) => s.toJson()).toList());
  }

  /// Updates fields of the schedule identified by [id].
  ///
  /// Only non-null parameters are included in the update payload.
  Future<void> updateSchedule(
    String id, {
    DateTime? date,
    String? userId,
    bool? isCompleted,
  }) async {
    final updates = <String, dynamic>{};
    if (date != null) {
      updates['date'] = date.toIso8601String().split('T').first;
    }
    if (userId != null) updates['user_id'] = userId;
    if (isCompleted != null) updates['is_completed'] = isCompleted;
    await SupabaseConfig.client.from('schedules').update(updates).eq('id', id);
  }

  /// Deletes the schedule identified by [id].
  Future<void> deleteSchedule(String id) async {
    await SupabaseConfig.client.from('schedules').delete().eq('id', id);
  }

  // --- Tasks ---

  /// Returns all active tasks ordered by sort_order.
  Future<List<CleaningTask>> getTasks() async {
    final data = await SupabaseConfig.client
        .from('tasks')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return data.map((json) => CleaningTask.fromJson(json)).toList();
  }

  /// Returns all tasks (including inactive) ordered by sort_order.
  Future<List<CleaningTask>> getAllTasks() async {
    final data = await SupabaseConfig.client
        .from('tasks')
        .select()
        .order('sort_order', ascending: true);
    return data.map((json) => CleaningTask.fromJson(json)).toList();
  }

  /// Creates a new task with the given [title] and [sortOrder].
  ///
  /// Optionally accepts a [description] that maps to the DB column
  /// description_task.
  Future<void> createTask(
    String title,
    int sortOrder, {
    String? description,
  }) async {
    final data = <String, dynamic>{'title': title, 'sort_order': sortOrder};
    if (description != null) data['description_task'] = description;
    await SupabaseConfig.client.from('tasks').insert(data);
  }

  /// Updates fields of the task identified by [id].
  ///
  /// Only non-null parameters are included in the update payload.
  Future<void> updateTask(
    String id, {
    String? title,
    int? sortOrder,
    bool? isActive,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;
    if (description != null) updates['description_task'] = description;
    await SupabaseConfig.client.from('tasks').update(updates).eq('id', id);
  }

  /// Deletes the task identified by [id].
  Future<void> deleteTask(String id) async {
    await SupabaseConfig.client.from('tasks').delete().eq('id', id);
  }

  // --- Comments ---

  /// Returns all comments for [scheduleId] ordered by creation time (newest first).
  Future<List<Comment>> getCommentsForSchedule(String scheduleId) async {
    final data = await SupabaseConfig.client
        .from('comments')
        .select()
        .eq('schedule_id', scheduleId)
        .order('created_at', ascending: false);
    return data.map((json) => Comment.fromJson(json)).toList();
  }

  /// Inserts a new comment for [scheduleId] with the given [message].
  Future<void> sendComment(String scheduleId, String message) async {
    await SupabaseConfig.client.from('comments').insert({
      'schedule_id': scheduleId,
      'message': message,
    });
  }

  /// Deletes all comments linked to [scheduleId].
  ///
  /// Called when a cleaning period is finalized to clean up ephemeral feedback.
  Future<void> deleteCommentsForSchedule(String scheduleId) async {
    await SupabaseConfig.client
        .from('comments')
        .delete()
        .eq('schedule_id', scheduleId);
  }

  // --- Extension Requests ---

  /// Returns all extension requests where [userId] is the requester or the
  /// next user, ordered by creation time (newest first).
  Future<List<ExtensionRequest>> getExtensionRequestsForUser(
    String userId,
  ) async {
    final data = await SupabaseConfig.client
        .from('extension_requests')
        .select()
        .or('requester_id.eq.$userId,next_user_id.eq.$userId')
        .order('created_at', ascending: false);
    return data.map((json) => ExtensionRequest.fromJson(json)).toList();
  }

  /// Returns all extension requests with status 'pending', ordered by
  /// creation time (newest first).
  Future<List<ExtensionRequest>> getPendingExtensionRequests() async {
    final data = await SupabaseConfig.client
        .from('extension_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return data.map((json) => ExtensionRequest.fromJson(json)).toList();
  }

  /// Returns the pending extension request for [scheduleId], or null if none.
  Future<ExtensionRequest?> getPendingRequestForSchedule(
    String scheduleId,
  ) async {
    final data = await SupabaseConfig.client
        .from('extension_requests')
        .select()
        .eq('schedule_id', scheduleId)
        .eq('status', 'pending')
        .maybeSingle();
    if (data == null) return null;
    return ExtensionRequest.fromJson(data);
  }

  /// Inserts a new extension request (prórroga) with status defaulting to
  /// 'pending' in the database.
  Future<void> createExtensionRequest({
    required String scheduleId,
    required String requesterId,
    required String nextUserId,
  }) async {
    await SupabaseConfig.client.from('extension_requests').insert({
      'schedule_id': scheduleId,
      'requester_id': requesterId,
      'next_user_id': nextUserId,
    });
  }

  /// Accepts the extension request identified by [requestId] and performs the
  /// schedule user-id swap between the requester and the next user.
  ///
  /// If no next schedule exists for [nextUserId] after the current schedule,
  /// only the current schedule's user is updated to [nextUserId].
  Future<void> acceptExtensionRequest(String requestId) async {
    final now = DateTime.now().toIso8601String();

    // Mark the request as accepted.
    await SupabaseConfig.client
        .from('extension_requests')
        .update({'status': 'accepted', 'resolved_at': now})
        .eq('id', requestId);

    // Fetch the request to get the schedule and user ids.
    final requestData = await SupabaseConfig.client
        .from('extension_requests')
        .select()
        .eq('id', requestId)
        .single();
    final request = ExtensionRequest.fromJson(requestData);

    // Fetch all schedules ordered by date.
    final schedules = await getSchedules();

    // Find the current schedule (the requester's week).
    final currentIndex = schedules.indexWhere(
      (s) => s.id == request.scheduleId,
    );
    if (currentIndex == -1) return;
    final currentSchedule = schedules[currentIndex];

    // Find the next schedule where userId == nextUserId and date is after
    // the current schedule's date.
    final nextSchedule = schedules
        .skip(currentIndex + 1)
        .where(
          (s) =>
              s.userId == request.nextUserId &&
              s.date.isAfter(currentSchedule.date),
        )
        .firstOrNull;

    // Swap user ids (or just update current if no next schedule exists).
    await SupabaseConfig.client
        .from('schedules')
        .update({'user_id': request.nextUserId})
        .eq('id', currentSchedule.id);

    if (nextSchedule != null) {
      await SupabaseConfig.client
          .from('schedules')
          .update({'user_id': request.requesterId})
          .eq('id', nextSchedule.id);
    }
  }

  /// Rejects the extension request identified by [requestId].
  Future<void> rejectExtensionRequest(String requestId) async {
    final now = DateTime.now().toIso8601String();
    await SupabaseConfig.client
        .from('extension_requests')
        .update({'status': 'rejected', 'resolved_at': now})
        .eq('id', requestId);
  }

  /// Returns all extension requests ordered by creation time (newest first).
  Future<List<ExtensionRequest>> getAllExtensionRequests() async {
    final data = await SupabaseConfig.client
        .from('extension_requests')
        .select()
        .order('created_at', ascending: false);
    return data.map((json) => ExtensionRequest.fromJson(json)).toList();
  }
}
