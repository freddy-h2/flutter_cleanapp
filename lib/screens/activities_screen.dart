import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/cleaning_task.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/admin/task_management_screen.dart';

/// Screen that shows the current user's cleaning task checklist for this week.
class ActivitiesScreen extends StatefulWidget {
  /// The currently authenticated user.
  final UserModel currentUser;

  /// Whether the current user is responsible for cleaning this week.
  ///
  /// Computed centrally in app.dart and passed down to avoid redundant queries.
  final bool isResponsible;

  /// Creates an [ActivitiesScreen].
  const ActivitiesScreen({
    super.key,
    required this.currentUser,
    required this.isResponsible,
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<CleaningTask> _tasks = [];
  bool _hasSchedule = false;
  bool _isLoading = true;
  CleaningSchedule? _currentSchedule;

  late final StreamSubscription<void> _tasksRealtimeSub;
  late final StreamSubscription<void> _schedulesRealtimeSub;
  late final StreamSubscription<void> _extensionsRealtimeSub;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _tasksRealtimeSub = RealtimeService.instance.onTasksChanged.listen((_) {
      if (mounted) {
        _loadTasks();
      }
    });
    _schedulesRealtimeSub = RealtimeService.instance.onSchedulesChanged.listen((
      _,
    ) {
      if (mounted) {
        _loadTasks();
      }
    });
    _extensionsRealtimeSub = RealtimeService.instance.onExtensionsChanged
        .listen((_) {
          if (mounted) {
            _loadTasks();
          }
        });
  }

  @override
  void dispose() {
    _tasksRealtimeSub.cancel();
    _schedulesRealtimeSub.cancel();
    _extensionsRealtimeSub.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      if (!widget.isResponsible) {
        if (mounted) {
          setState(() {
            _currentSchedule = null;
            _hasSchedule = false;
            _tasks = [];
            _isLoading = false;
          });
        }
        return;
      }

      // User is responsible — find their current period schedule and load tasks.
      final schedule = await SupabaseService.instance
          .getCurrentPeriodSchedule();

      if (schedule != null && schedule.userId == widget.currentUser.id) {
        final tasks = await SupabaseService.instance.getTasks();
        if (mounted) {
          setState(() {
            _currentSchedule = schedule;
            _hasSchedule = true;
            _tasks = tasks;
            _isLoading = false;
          });
        }
      } else {
        // Fallback: isResponsible is true but no matching schedule found.
        // This should not happen, but handle gracefully.
        if (mounted) {
          setState(() {
            _currentSchedule = null;
            _hasSchedule = false;
            _tasks = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar actividades: $e')),
        );
      }
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

  Future<void> _finalize() async {
    final colorScheme = Theme.of(context).colorScheme;
    if (_currentSchedule != null) {
      try {
        // Mark the schedule as completed
        await SupabaseService.instance.updateSchedule(
          _currentSchedule!.id,
          isCompleted: true,
        );
        // Delete all comments for this schedule
        await SupabaseService.instance.deleteCommentsForSchedule(
          _currentSchedule!.id,
        );
      } catch (e) {
        // Ignore errors — still show success message locally
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Aseo completado! Gracias por tu colaboración'),
          backgroundColor: colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _navigateToTaskManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TaskManagementScreen()),
    );
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!_hasSchedule) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('¡Estás libre esta semana!', style: textTheme.bodyLarge),
            if (widget.currentUser.isAdmin) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _navigateToTaskManagement,
                icon: const Icon(Icons.edit),
                label: const Text('Editar Actividades'),
              ),
            ],
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Actividades de Aseo',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.currentUser.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar actividades',
                      onPressed: _navigateToTaskManagement,
                    ),
                ],
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
              return ListTile(
                onTap: () => _toggleTask(index),
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.isCompleted
                        ? colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                subtitle: task.description.isNotEmpty
                    ? Text(task.description)
                    : null,
                trailing: Icon(
                  task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                  color: task.isCompleted
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
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
