import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/admin/schedule_management_screen.dart';

/// Displays the upcoming cleaning schedule for all residents.
class CalendarScreen extends StatefulWidget {
  /// The currently authenticated user.
  final UserModel currentUser;

  /// Creates a [CalendarScreen].
  const CalendarScreen({super.key, required this.currentUser});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<CleaningSchedule> _schedules = [];
  List<UserModel> _users = [];
  List<ExtensionRequest> _extensionRequests = [];
  bool _isLoading = true;

  late final StreamSubscription<void> _schedulesRealtimeSub;
  late final StreamSubscription<void> _extensionsRealtimeSub;

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

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _schedulesRealtimeSub = RealtimeService.instance.onSchedulesChanged.listen((
      _,
    ) {
      if (mounted) {
        _loadSchedules();
      }
    });
    _extensionsRealtimeSub = RealtimeService.instance.onExtensionsChanged
        .listen((_) {
          if (mounted) {
            _loadSchedules();
          }
        });
  }

  @override
  void dispose() {
    _schedulesRealtimeSub.cancel();
    _extensionsRealtimeSub.cancel();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await SupabaseService.instance.getSchedules();
      final users = await SupabaseService.instance.getUsers();
      final requests = widget.currentUser.isAdmin
          ? await SupabaseService.instance.getAllExtensionRequests()
          : await SupabaseService.instance.getExtensionRequestsForUser(
              widget.currentUser.id,
            );
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _users = users;
          _extensionRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar calendario: $e')),
        );
      }
    }
  }

  /// Returns the extension request for [schedule], or null if none.
  ///
  /// First tries an exact match by [CleaningSchedule.id]. If none is found,
  /// also checks whether this schedule was the "other side" of an accepted
  /// swap: after acceptance the next user's schedule has [requesterId] as its
  /// [userId], so we match on that.
  ExtensionRequest? _getRequestForSchedule(CleaningSchedule schedule) {
    // First try exact match by scheduleId (covers the original/requester schedule)
    final exactMatch = _extensionRequests
        .where((r) => r.scheduleId == schedule.id)
        .firstOrNull;
    if (exactMatch != null) return exactMatch;

    // For accepted requests, also check if this schedule was the 'other side'
    // of a swap. After acceptance, the next user's schedule now has requesterId
    // as its userId. So if schedule.userId == request.requesterId AND the
    // request is accepted, this schedule was the one that received the
    // requester in the swap.
    return _extensionRequests
        .where(
          (r) =>
              r.status == ExtensionRequestStatus.accepted &&
              r.requesterId == schedule.userId,
        )
        .firstOrNull;
  }

  /// Returns true if [schedule.date] falls within the current 3-day period.
  ///
  /// The current period spans from [today - (cleaningPeriodDays - 1)] to today.
  bool _isCurrentPeriod(CleaningSchedule schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = today.subtract(
      const Duration(days: SupabaseService.cleaningPeriodDays - 1),
    );
    final d = DateTime(
      schedule.date.year,
      schedule.date.month,
      schedule.date.day,
    );
    return !d.isBefore(periodStart) && !d.isAfter(today);
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
    return schedule.userId == widget.currentUser.id;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      // Sort schedules by date ascending.
      final schedules = List<CleaningSchedule>.from(_schedules)
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
        final user = _users.firstWhere(
          (u) => u.id == schedule.userId,
          orElse: () => const UserModel(id: '', name: '?', room: ''),
        );
        items.add(_ScheduleEntry(schedule: schedule, user: user));
      }

      body = Column(
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
                final currentWeek = _isCurrentPeriod(schedule);
                final currentUser = _isCurrentUser(schedule);
                final request = _getRequestForSchedule(schedule);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  shape: currentUser
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.primary,
                            width: 4,
                          ),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.room} — Periodo del ${_formatDate(schedule.date)}',
                        ),
                        if (request != null && request.isPending)
                          Chip(
                            label: const Text('Prórroga pendiente'),
                            avatar: const Icon(Icons.schedule, size: 16),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: colorScheme.tertiaryContainer,
                          ),
                        if (request != null &&
                            request.status == ExtensionRequestStatus.accepted)
                          Chip(
                            label: const Text('Prórroga aceptada'),
                            avatar: const Icon(Icons.swap_horiz, size: 16),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: colorScheme.secondaryContainer,
                          ),
                      ],
                    ),
                    trailing: schedule.isCompleted
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : currentWeek
                        ? Chip(
                            label: const Text('Este periodo'),
                            backgroundColor: colorScheme.primaryContainer,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: widget.currentUser.isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScheduleManagementScreen(),
                  ),
                );
                await _loadSchedules();
              },
              tooltip: 'Gestionar calendario',
              child: const Icon(Icons.edit_calendar),
            )
          : null,
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
