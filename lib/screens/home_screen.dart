import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/mock_data.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Home screen that shows the current user's cleaning status for the week.
class HomeScreen extends StatelessWidget {
  /// Callback invoked when the user taps "Ir a Actividades".
  final VoidCallback onNavigateToActivities;

  /// Creates a [HomeScreen].
  const HomeScreen({super.key, required this.onNavigateToActivities});

  /// Returns the Monday of the week containing [date].
  DateTime _mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  /// Formats a [DateTime] as "dd/MM/yyyy".
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final UserModel currentUser = MockData.currentUser;
    final List<CleaningSchedule> schedules = MockData.schedules;

    final now = DateTime.now();
    final thisMonday = _mondayOf(now);
    final thisSunday = thisMonday.add(const Duration(days: 6));

    // Find the schedule entry for the current week.
    CleaningSchedule? currentWeekSchedule;
    for (final s in schedules) {
      final weekMonday = _mondayOf(s.date);
      if (!weekMonday.isBefore(thisMonday) && !weekMonday.isAfter(thisMonday)) {
        currentWeekSchedule = s;
        break;
      }
    }

    // Determine if the current user is responsible this week.
    final bool isResponsible =
        currentWeekSchedule != null &&
        currentWeekSchedule.userId == currentUser.id &&
        !currentWeekSchedule.isCompleted;

    if (isResponsible) {
      // State A — user has cleaning duty this week.
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 80,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '¡Te toca hacer el aseo!',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Semana del ${_formatDate(thisMonday)} al ${_formatDate(thisSunday)}',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(currentUser.name),
                subtitle: Text(currentUser.apartment),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.checklist),
              label: const Text('Ir a Actividades'),
              onPressed: onNavigateToActivities,
            ),
          ],
        ),
      );
    }

    // State B — user is free this week; find next turn.
    CleaningSchedule? nextSchedule;
    for (final s in schedules) {
      if (s.userId == currentUser.id && s.date.isAfter(now)) {
        if (nextSchedule == null || s.date.isBefore(nextSchedule.date)) {
          nextSchedule = s;
        }
      }
    }

    final String nextDateText = nextSchedule != null
        ? _formatDate(_mondayOf(nextSchedule.date))
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '¡Estás libre esta semana!',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tu próximo turno es la semana del $nextDateText',
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(currentUser.name),
              subtitle: Text(currentUser.apartment),
            ),
          ),
        ],
      ),
    );
  }
}
