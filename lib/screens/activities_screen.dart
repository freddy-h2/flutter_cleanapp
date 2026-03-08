import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/mock_data.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';

/// Screen that shows the current user's cleaning task checklist for this week.
class ActivitiesScreen extends StatefulWidget {
  /// Creates an [ActivitiesScreen].
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<CleaningTask> _tasks = [];
  bool _hasSchedule = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    final currentUser = MockData.currentUser;
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStart = DateTime(
      currentMonday.year,
      currentMonday.month,
      currentMonday.day,
    );
    final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));

    final schedule = MockData.schedules.where((s) {
      return s.userId == currentUser.id &&
          !s.date.isBefore(currentWeekStart) &&
          s.date.isBefore(currentWeekEnd);
    }).firstOrNull;

    if (schedule != null) {
      _hasSchedule = true;
      _tasks = MockData.tasksForSchedule(schedule.id);
    } else {
      _hasSchedule = false;
      _tasks = [];
    }
  }

  bool get _allCompleted =>
      _tasks.isNotEmpty && _tasks.every((t) => t.isCompleted);

  void _toggleTask(int index) {
    setState(() {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
    });
  }

  void _showIncompleteWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Aún tienes tareas pendientes por completar')),
          ],
        ),
      ),
    );
  }

  void _finalize() {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¡Aseo completado! Gracias por tu colaboración'),
        backgroundColor: colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!_hasSchedule) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No tienes aseo asignado esta semana',
              style: textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actividades de Aseo',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Marca cada tarea al completarla',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return CheckboxListTile(
                value: task.isCompleted,
                onChanged: (value) => _toggleTask(index),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                secondary: Icon(
                  task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: task.isCompleted
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _allCompleted ? _finalize : _showIncompleteWarning,
                icon: const Icon(Icons.done_all),
                label: const Text('Finalizar Aseo'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
