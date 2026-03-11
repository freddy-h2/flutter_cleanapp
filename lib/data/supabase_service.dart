import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/models/announcement.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';
import 'package:flutter_cleanapp/models/feedback_model.dart';
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
  ///
  /// Optionally accepts a [color] (ARGB32 integer) to update the user's color.
  /// Pass [clearColor] as true to reset the color to null (default).
  Future<void> updateProfile({
    String? name,
    String? room,
    int? color,
    bool clearColor = false,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (room != null) updates['room'] = room;
    if (color != null) updates['color'] = color;
    if (clearColor) updates['color'] = null;
    if (updates.isEmpty) return;
    await SupabaseConfig.client
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }

  /// Updates the color of the user with [userId].
  ///
  /// [colorValue] is an ARGB32 integer, or null to reset to default.
  Future<void> updateUserColor(String userId, int? colorValue) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({'color': colorValue})
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

  /// Returns the first schedule in the current cleaning period (3-day window),
  /// or null if no schedule exists for this period.
  ///
  /// The period window is [today - (cleaningPeriodDays - 1), today].
  /// This matches the logic in app.dart _computeResponsibleStatus().
  Future<CleaningSchedule?> getCurrentPeriodSchedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = today.subtract(
      const Duration(days: cleaningPeriodDays - 1),
    );
    final data = await SupabaseConfig.client
        .from('schedules')
        .select()
        .gte('date', periodStart.toIso8601String().split('T').first)
        .lte('date', today.toIso8601String().split('T').first)
        .order('date')
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
  ///
  /// If [senderId] is provided, the comment is attributed to that user.
  /// If null, the comment is anonymous.
  /// If [parentId] is provided, this comment is a reply to that comment.
  Future<void> sendComment(
    String scheduleId,
    String message, {
    String? senderId,
    String? parentId,
  }) async {
    final data = <String, dynamic>{
      'schedule_id': scheduleId,
      'message': message,
    };
    if (senderId != null) data['sender_id'] = senderId;
    if (parentId != null) data['parent_id'] = parentId;
    await SupabaseConfig.client.from('comments').insert(data);
  }

  /// Returns all replies to the comment with [parentId], ordered by creation
  /// time ascending (oldest first, for chat-like display).
  Future<List<Comment>> getRepliesForComment(String parentId) async {
    final data = await SupabaseConfig.client
        .from('comments')
        .select()
        .eq('parent_id', parentId)
        .order('created_at', ascending: true);
    return data.map((json) => Comment.fromJson(json)).toList();
  }

  /// Returns all top-level comments for [scheduleId] with their replies.
  ///
  /// Returns a map where keys are top-level [Comment] objects and values are
  /// lists of reply [Comment] objects (sorted by creation time ascending).
  /// Top-level comments are sorted by creation time descending (newest first).
  Future<Map<Comment, List<Comment>>> getCommentsWithReplies(
    String scheduleId,
  ) async {
    // Fetch all comments for this schedule (top-level + replies)
    final data = await SupabaseConfig.client
        .from('comments')
        .select()
        .eq('schedule_id', scheduleId)
        .order('created_at', ascending: true);
    final allComments = data.map((json) => Comment.fromJson(json)).toList();

    // Separate top-level comments from replies
    final topLevel = allComments.where((c) => c.parentId == null).toList();
    final replies = allComments.where((c) => c.parentId != null).toList();

    // Build the map
    final result = <Comment, List<Comment>>{};
    for (final comment in topLevel.reversed) {
      // reversed because we want newest first for top-level
      result[comment] = replies.where((r) => r.parentId == comment.id).toList();
    }
    return result;
  }

  /// Returns all comments sent by [senderId] for [scheduleId], with their
  /// replies, ordered by creation time descending.
  Future<Map<Comment, List<Comment>>> getCommentsBySender(
    String scheduleId,
    String senderId,
  ) async {
    // Fetch comments sent by this user for this schedule
    final sentData = await SupabaseConfig.client
        .from('comments')
        .select()
        .eq('schedule_id', scheduleId)
        .eq('sender_id', senderId)
        .isFilter('parent_id', null)
        .order('created_at', ascending: false);
    final sentComments = sentData
        .map((json) => Comment.fromJson(json))
        .toList();

    // Fetch all replies to those comments
    final result = <Comment, List<Comment>>{};
    for (final comment in sentComments) {
      final repliesData = await SupabaseConfig.client
          .from('comments')
          .select()
          .eq('parent_id', comment.id)
          .order('created_at', ascending: true);
      result[comment] = repliesData
          .map((json) => Comment.fromJson(json))
          .toList();
    }
    return result;
  }

  /// Updates the [message] of an existing comment identified by [commentId].
  ///
  /// The Supabase RLS policy only allows the comment's sender to update it.
  Future<void> updateComment(String commentId, String message) async {
    await SupabaseConfig.client
        .from('comments')
        .update({'message': message})
        .eq('id', commentId);
  }

  /// Deletes a single comment identified by [commentId].
  ///
  /// The Supabase RLS policy only allows the comment's sender to delete it.
  /// Replies are cascade-deleted by the database foreign key constraint.
  Future<void> deleteComment(String commentId) async {
    await SupabaseConfig.client.from('comments').delete().eq('id', commentId);
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

  /// Finds the cleaning period schedules around [anchor].
  ///
  /// A period is defined as up to [maxSize] consecutive same-user schedules
  /// where each date is at most 1 day apart from its neighbor. When [maxSize]
  /// is provided, the result is capped to at most [maxSize] entries.
  ///
  /// The search is bounded to [maxSize] days before and after the anchor
  /// date to prevent crossing into adjacent periods of the same user.
  ///
  /// Retained for use by tests and potential future callers.
  // ignore: unused_element
  List<CleaningSchedule> _findPeriodSchedules(
    List<CleaningSchedule> sortedSchedules,
    CleaningSchedule anchor, {
    int? maxSize,
  }) {
    final anchorIndex = sortedSchedules.indexWhere((s) => s.id == anchor.id);
    if (anchorIndex == -1) return [anchor];

    final userId = anchor.userId;
    final anchorDate = DateTime(
      anchor.date.year,
      anchor.date.month,
      anchor.date.day,
    );

    // Define the maximum date range for this period.
    final maxDays = maxSize ?? 365; // fallback to large number if no cap
    final earliestDate = anchorDate.subtract(Duration(days: maxDays - 1));
    final latestDate = anchorDate.add(Duration(days: maxDays - 1));

    final result = <CleaningSchedule>[anchor];

    // Walk backward.
    for (var i = anchorIndex - 1; i >= 0; i--) {
      if (sortedSchedules[i].userId != userId) break;
      final schedDate = DateTime(
        sortedSchedules[i].date.year,
        sortedSchedules[i].date.month,
        sortedSchedules[i].date.day,
      );
      // Stop if date is outside the allowed range.
      if (schedDate.isBefore(earliestDate)) break;
      final diff = sortedSchedules[i + 1].date
          .difference(sortedSchedules[i].date)
          .inDays;
      if (diff > 1) break;
      result.insert(0, sortedSchedules[i]);
      if (maxSize != null && result.length >= maxSize) break;
    }

    // Walk forward.
    for (var i = anchorIndex + 1; i < sortedSchedules.length; i++) {
      if (maxSize != null && result.length >= maxSize) break;
      if (sortedSchedules[i].userId != userId) break;
      final schedDate = DateTime(
        sortedSchedules[i].date.year,
        sortedSchedules[i].date.month,
        sortedSchedules[i].date.day,
      );
      // Stop if date is outside the allowed range.
      if (schedDate.isAfter(latestDate)) break;
      final diff = sortedSchedules[i].date
          .difference(sortedSchedules[i - 1].date)
          .inDays;
      if (diff > 1) break;
      result.add(sortedSchedules[i]);
    }

    return result;
  }

  /// Accepts the extension request identified by [requestId] and performs the
  /// schedule user-id swap between the requester and the next user.
  ///
  /// Delegates all logic to the `accept_extension_swap` RPC function which
  /// handles the swap atomically server-side with SECURITY DEFINER privileges.
  Future<void> acceptExtensionRequest(String requestId) async {
    await SupabaseConfig.client.rpc(
      'accept_extension_swap',
      params: {'p_request_id': requestId},
    );
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

  /// Cancels a pending extension request by marking it as rejected.
  ///
  /// Used when the requester wants to withdraw their own request before
  /// the next user responds. Only affects requests with status 'pending'.
  Future<void> cancelExtensionRequest(String requestId) async {
    final now = DateTime.now().toIso8601String();
    await SupabaseConfig.client
        .from('extension_requests')
        .update({'status': 'rejected', 'resolved_at': now})
        .eq('id', requestId)
        .eq('status', 'pending');
  }

  /// Returns all accepted extension requests where [userId] is the requester,
  /// ordered by creation time (newest first).
  ///
  /// Used to enforce the per-cycle prórroga limit.
  Future<List<ExtensionRequest>> getAcceptedRequestsForRequester(
    String userId,
  ) async {
    final data = await SupabaseConfig.client
        .from('extension_requests')
        .select()
        .eq('requester_id', userId)
        .eq('status', 'accepted')
        .order('created_at', ascending: false);
    return data.map((json) => ExtensionRequest.fromJson(json)).toList();
  }

  // --- Feedback ---

  /// Sends anonymous app feedback.
  Future<void> sendFeedback(String message) async {
    await SupabaseConfig.client.from('feedback').insert({'message': message});
  }

  /// Returns all feedback entries (admin only), newest first.
  Future<List<FeedbackModel>> getAllFeedback() async {
    final data = await SupabaseConfig.client
        .from('feedback')
        .select()
        .order('created_at', ascending: false);
    return data.map((json) => FeedbackModel.fromJson(json)).toList();
  }

  /// Deletes a feedback entry (admin only).
  Future<void> deleteFeedback(String feedbackId) async {
    await SupabaseConfig.client.from('feedback').delete().eq('id', feedbackId);
  }

  // --- Announcements ---

  /// Creates a new announcement (admin only).
  ///
  /// If [type] is [AnnouncementType.update], all existing active update
  /// announcements are deactivated first so only the newest one stays active.
  Future<void> createAnnouncement({
    required String senderId,
    required String title,
    required String message,
    required AnnouncementType type,
    String? link,
  }) async {
    // If publishing a new update, deactivate all previous active updates.
    if (type == AnnouncementType.update) {
      await SupabaseConfig.client
          .from('announcements')
          .update({'is_active': false})
          .eq('type', 'update')
          .eq('is_active', true);
    }
    await SupabaseConfig.client.from('announcements').insert({
      'sender_id': senderId,
      'title': title,
      'message': message,
      'type': type.name,
      'link': link,
    });
  }

  /// Returns all active announcements, newest first.
  Future<List<Announcement>> getActiveAnnouncements() async {
    final data = await SupabaseConfig.client
        .from('announcements')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return data.map((json) => Announcement.fromJson(json)).toList();
  }

  /// Returns all announcements (admin), newest first.
  Future<List<Announcement>> getAllAnnouncements() async {
    final data = await SupabaseConfig.client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return data.map((json) => Announcement.fromJson(json)).toList();
  }

  /// Deactivates an announcement (admin only).
  Future<void> deactivateAnnouncement(String announcementId) async {
    await SupabaseConfig.client
        .from('announcements')
        .update({'is_active': false})
        .eq('id', announcementId);
  }

  /// Reactivates a previously deactivated announcement.
  Future<void> activateAnnouncement(String announcementId) async {
    await SupabaseConfig.client
        .from('announcements')
        .update({'is_active': true})
        .eq('id', announcementId);
  }

  /// Deletes an announcement (admin only).
  ///
  /// Should only be called on inactive announcements.
  Future<void> deleteAnnouncement(String announcementId) async {
    await SupabaseConfig.client
        .from('announcements')
        .delete()
        .eq('id', announcementId);
  }

  // --- Maintenance ---

  /// Deletes completed schedules older than 7 days.
  ///
  /// Returns the number of deleted schedules.
  Future<int> cleanupOldSchedules() async {
    final result = await SupabaseConfig.client.rpc('cleanup_old_schedules');
    return (result as int?) ?? 0;
  }

  /// Updates an existing announcement (admin only).
  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String message,
    required AnnouncementType type,
    String? link,
  }) async {
    await SupabaseConfig.client
        .from('announcements')
        .update({
          'title': title,
          'message': message,
          'type': type.name,
          'link': link,
        })
        .eq('id', announcementId);
  }
}
