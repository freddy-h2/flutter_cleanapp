import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';
import 'package:flutter_cleanapp/models/comment.dart';
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
  Future<UserModel?> getCurrentUser() async {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser == null) return null;
    final data = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', authUser.id)
        .single();
    return UserModel.fromJson(data);
  }

  // --- Profiles ---

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

  /// Returns all cleaning schedules ordered by date.
  Future<List<CleaningSchedule>> getSchedules() async {
    final data = await SupabaseConfig.client
        .from('schedules')
        .select()
        .order('date');
    return data.map((json) => CleaningSchedule.fromJson(json)).toList();
  }

  /// Returns the schedule for the current calendar week, or null if none.
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
        .order('sort_order');
    return data.map((json) => CleaningTask.fromJson(json)).toList();
  }

  /// Returns all tasks (including inactive) ordered by sort_order.
  Future<List<CleaningTask>> getAllTasks() async {
    final data = await SupabaseConfig.client
        .from('tasks')
        .select()
        .order('sort_order');
    return data.map((json) => CleaningTask.fromJson(json)).toList();
  }

  /// Creates a new task with the given [title] and [sortOrder].
  Future<void> createTask(String title, int sortOrder) async {
    await SupabaseConfig.client.from('tasks').insert({
      'title': title,
      'sort_order': sortOrder,
    });
  }

  /// Updates fields of the task identified by [id].
  ///
  /// Only non-null parameters are included in the update payload.
  Future<void> updateTask(
    String id, {
    String? title,
    int? sortOrder,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;
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
}
