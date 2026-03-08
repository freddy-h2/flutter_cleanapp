import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/mock_data.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Displays the upcoming cleaning schedule for all residents.
class CalendarScreen extends StatelessWidget {
  /// Creates a [CalendarScreen].
  const CalendarScreen({super.key});

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Returns true if [schedule.date] falls within the current Monday–Sunday.
  bool _isCurrentWeek(CleaningSchedule schedule) {
    final now = DateTime.now();
    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final currentSunday = currentMonday.add(const Duration(days: 6));
    final d = schedule.date;
    return !d.isBefore(currentMonday) && !d.isAfter(currentSunday);
  }

  /// Returns [date] formatted as "dd/MM/yyyy".
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  /// Returns true if [schedule] belongs to the currently logged-in user.
  bool _isCurrentUser(CleaningSchedule schedule) {
    return schedule.userId == MockData.currentUser.id;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Sort schedules by date ascending.
    final schedules = List<CleaningSchedule>.from(MockData.schedules)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Build a flat list of items: month headers + schedule entries.
    final items = <_ListItem>[];
    int? lastMonth;
    for (final schedule in schedules) {
      if (lastMonth != schedule.date.month) {
        items.add(
          _MonthHeader(
            label:
                '${_monthNames[schedule.date.month - 1]} ${schedule.date.year}',
          ),
        );
        lastMonth = schedule.date.month;
      }
      final user = MockData.users.firstWhere(
        (u) => u.id == schedule.userId,
        orElse: () => const UserModel(id: '', name: '?', apartment: ''),
      );
      items.add(_ScheduleEntry(schedule: schedule, user: user));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendario de Aseo',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Próximas fechas de limpieza',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is _MonthHeader) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    item.label,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final entry = item as _ScheduleEntry;
              final schedule = entry.schedule;
              final user = entry.user;
              final currentWeek = _isCurrentWeek(schedule);
              final currentUser = _isCurrentUser(schedule);

              final card = Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: currentUser
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.primary, width: 4),
                      )
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: currentWeek
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: currentWeek
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    child: Text(user.name[0]),
                  ),
                  title: Text(user.name),
                  subtitle: Text(
                    '${user.apartment} — Semana del ${_formatDate(schedule.date)}',
                  ),
                  trailing: schedule.isCompleted
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : currentWeek
                      ? Chip(
                          label: const Text('Esta semana'),
                          backgroundColor: colorScheme.primaryContainer,
                        )
                      : null,
                ),
              );

              return card;
            },
          ),
        ),
      ],
    );
  }
}

/// Base class for items in the schedule list.
sealed class _ListItem {}

/// A month separator header item.
final class _MonthHeader extends _ListItem {
  _MonthHeader({required this.label});
  final String label;
}

/// A schedule entry item.
final class _ScheduleEntry extends _ListItem {
  _ScheduleEntry({required this.schedule, required this.user});
  final CleaningSchedule schedule;
  final UserModel user;
}
