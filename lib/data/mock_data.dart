import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';
import 'package:flutter_cleanapp/models/comment.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Provides hardcoded mock data for the entire app.
///
/// This replaces Supabase until backend integration is complete.
abstract final class MockData {
  /// The currently "logged in" user (always the first user for now).
  static UserModel get currentUser => users.first;

  /// All residents in the building.
  static List<UserModel> get users => [
    const UserModel(id: 'u1', name: 'Carlos García', apartment: 'Depto 1A'),
    const UserModel(id: 'u2', name: 'María López', apartment: 'Depto 2B'),
    const UserModel(id: 'u3', name: 'Juan Martínez', apartment: 'Depto 3A'),
    const UserModel(id: 'u4', name: 'Ana Rodríguez', apartment: 'Depto 4B'),
  ];

  /// Cleaning schedule entries — one per user, rotating weekly.
  ///
  /// Generates entries for the past 2 weeks and next 6 weeks (8 total entries).
  static List<CleaningSchedule> get schedules {
    final now = DateTime.now();
    // Find the Monday of the current week.
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStart = DateTime(
      currentMonday.year,
      currentMonday.month,
      currentMonday.day,
    );

    // Start from 2 weeks ago.
    final startMonday = currentWeekStart.subtract(const Duration(days: 14));

    final userIds = ['u1', 'u2', 'u3', 'u4'];
    final result = <CleaningSchedule>[];

    for (var i = 0; i < 8; i++) {
      final weekStart = startMonday.add(Duration(days: i * 7));
      final isPast = weekStart.isBefore(currentWeekStart);
      result.add(
        CleaningSchedule(
          id: 's$i',
          userId: userIds[i % userIds.length],
          date: weekStart,
          isCompleted: isPast,
        ),
      );
    }

    return result;
  }

  /// Returns the 8 cleaning tasks for a given schedule.
  static List<CleaningTask> tasksForSchedule(String scheduleId) {
    return List.generate(
      defaultTaskTitles.length,
      (index) => CleaningTask(
        id: '${scheduleId}_t$index',
        scheduleId: scheduleId,
        title: defaultTaskTitles[index],
      ),
    );
  }

  /// Default task titles in Spanish.
  static const List<String> defaultTaskTitles = [
    'Lavar el retrete',
    'Lavar el lavamanos',
    'Lavar la regadera',
    'Barrer',
    'Trapear',
    'Secar el piso',
    'Sacar la basura',
    'Limpiar las jergas',
  ];

  /// Sample anonymous comments for the current week schedule.
  /// Returns comments that were "sent" to the person responsible this week.
  static List<Comment> get commentsForCurrentSchedule {
    final currentSchedule = _currentWeekSchedule;
    if (currentSchedule == null) return [];
    return [
      Comment(
        id: 'c1',
        scheduleId: currentSchedule.id,
        message:
            'Recuerda limpiar bien detrás del retrete, la última vez quedó sucio.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Comment(
        id: 'c2',
        scheduleId: currentSchedule.id,
        message:
            'Por favor no olvides sacar la basura del bote pequeño también.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Comment(
        id: 'c3',
        scheduleId: currentSchedule.id,
        message: '¡Gracias por mantener limpio el baño! Se aprecia mucho.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  /// Helper: find the schedule for the current week, or null.
  static CleaningSchedule? get _currentWeekSchedule {
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      currentMonday.year,
      currentMonday.month,
      currentMonday.day,
    );
    final weekEnd = weekStart.add(const Duration(days: 7));
    try {
      return schedules.firstWhere(
        (s) => !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd),
      );
    } catch (_) {
      return null;
    }
  }

  /// The user responsible for cleaning this week, or null.
  static UserModel? get currentWeekResponsible {
    final schedule = _currentWeekSchedule;
    if (schedule == null) return null;
    try {
      return users.firstWhere((u) => u.id == schedule.userId);
    } catch (_) {
      return null;
    }
  }
}
