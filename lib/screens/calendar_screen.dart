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
  bool _isGridView = false;
  late DateTime _gridMonth;

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

  static const List<String> _dayHeaders = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _gridMonth = DateTime(now.year, now.month);
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

  /// Builds the list view of schedules.
  Widget _buildListView(
    List<_ListItem> items,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return ListView.builder(
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
        final period = item as _PeriodEntry;
        final user = period.user;
        final firstDate = period.schedules.first.date;
        final lastDate = period.schedules.last.date;
        final isCurrentPeriod = period.schedules.any(_isCurrentPeriod);
        final isCurrentUser = period.schedules.any(_isCurrentUser);
        final allCompleted = period.schedules.every((s) => s.isCompleted);
        // Find the first matching extension request across all
        // schedules in the group.
        final request = period.schedules
            .map(_getRequestForSchedule)
            .nonNulls
            .firstOrNull;

        final subtitleText = period.schedules.length > 1
            ? '${user.room} — Periodo del '
                  '${_formatDate(firstDate)} al '
                  '${_formatDate(lastDate)}'
            : '${user.room} — Periodo del ${_formatDate(firstDate)}';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: isCurrentUser
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.primary, width: 4),
                )
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrentPeriod
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: isCurrentPeriod
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              child: Text(user.name[0]),
            ),
            title: Text(user.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitleText),
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
            trailing: allCompleted
                ? Icon(Icons.check_circle, color: colorScheme.primary)
                : isCurrentPeriod
                ? Chip(
                    label: const Text('Este periodo'),
                    backgroundColor: colorScheme.primaryContainer,
                  )
                : null,
          ),
        );
      },
    );
  }

  /// Builds the grid (calendar) view of schedules.
  Widget _buildGridView(
    List<CleaningSchedule> schedules,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // Build a map of date -> schedule for quick lookup.
    final scheduleMap = <DateTime, CleaningSchedule>{};
    for (final s in schedules) {
      final dateOnly = DateTime(s.date.year, s.date.month, s.date.day);
      scheduleMap[dateOnly] = s;
    }

    // Build user color map.
    final userColors = <String, Color>{};
    for (var i = 0; i < _users.length; i++) {
      userColors[_users[i].id] = Colors.primaries[i % Colors.primaries.length];
    }

    // Calculate grid layout for _gridMonth.
    final firstDayOfMonth = DateTime(_gridMonth.year, _gridMonth.month, 1);
    final lastDayOfMonth = DateTime(_gridMonth.year, _gridMonth.month + 1, 0);
    // Monday = 1, so offset = (firstDayOfMonth.weekday - 1)
    final startOffset = firstDayOfMonth.weekday - 1; // 0 = Monday
    final totalDays = lastDayOfMonth.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Month navigation.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _gridMonth = DateTime(_gridMonth.year, _gridMonth.month - 1);
              }),
            ),
            Text(
              '${_monthNames[_gridMonth.month - 1]} ${_gridMonth.year}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _gridMonth = DateTime(_gridMonth.year, _gridMonth.month + 1);
              }),
            ),
          ],
        ),
        // Day-of-week headers.
        Row(
          children: _dayHeaders
              .map(
                (h) => Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Day grid.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: rows * 7,
          itemBuilder: (context, index) {
            final dayIndex = index - startOffset + 1;
            final isCurrentMonth = dayIndex >= 1 && dayIndex <= totalDays;

            if (!isCurrentMonth) {
              // Show empty cell for days outside current month.
              return const SizedBox.shrink();
            }

            final cellDate = DateTime(
              _gridMonth.year,
              _gridMonth.month,
              dayIndex,
            );
            final schedule = scheduleMap[cellDate];
            final isToday = cellDate == today;

            Color? bgColor;
            String? initial;
            bool isCompleted = false;

            if (schedule != null) {
              final baseColor = userColors[schedule.userId];
              if (baseColor != null) {
                bgColor = baseColor.withValues(alpha: 0.3);
              }
              final user = _users.firstWhere(
                (u) => u.id == schedule.userId,
                orElse: () => const UserModel(id: '', name: '?', room: ''),
              );
              initial = user.name.isNotEmpty ? user.name[0] : '?';
              isCompleted = schedule.isCompleted;
            }

            return Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: isToday
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayIndex',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (initial != null)
                        Text(
                          initial,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                  if (isCompleted)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Icon(
                        Icons.check,
                        size: 10,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Legend.
        if (_users.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < _users.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.primaries[i % Colors.primaries.length]
                              .withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_users[i].name} (${_users[i].room})',
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
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

      // Group consecutive same-user schedules into period entries.
      final periods = <_PeriodEntry>[];
      for (final schedule in schedules) {
        final user = _users.firstWhere(
          (u) => u.id == schedule.userId,
          orElse: () => const UserModel(id: '', name: '?', room: ''),
        );
        if (periods.isNotEmpty && periods.last.user.id == schedule.userId) {
          periods.last.schedules.add(schedule);
        } else {
          periods.add(_PeriodEntry(schedules: [schedule], user: user));
        }
      }

      // Build a flat list of items: month headers + period entries.
      final items = <_ListItem>[];
      int? lastMonth;
      for (final period in periods) {
        final firstDate = period.schedules.first.date;
        if (lastMonth != firstDate.month) {
          items.add(
            _MonthHeader(
              label: '${_monthNames[firstDate.month - 1]} ${firstDate.year}',
            ),
          );
          lastMonth = firstDate.month;
        }
        items.add(period);
      }

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Calendario de Aseo',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isGridView
                            ? Icons.view_list
                            : Icons.calendar_view_month,
                      ),
                      tooltip: _isGridView
                          ? 'Vista de lista'
                          : 'Vista de calendario',
                      onPressed: () =>
                          setState(() => _isGridView = !_isGridView),
                    ),
                  ],
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
            child: _isGridView
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildGridView(schedules, colorScheme, textTheme),
                  )
                : _buildListView(items, colorScheme, textTheme),
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

/// A grouped period entry — one or more consecutive same-user schedules.
final class _PeriodEntry extends _ListItem {
  _PeriodEntry({required this.schedules, required this.user});
  final List<CleaningSchedule> schedules;
  final UserModel user;
}
