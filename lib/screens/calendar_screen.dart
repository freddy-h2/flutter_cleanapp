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
    // Only show loading indicator on initial load, not on realtime refreshes.
    if (_schedules.isEmpty) {
      setState(() => _isLoading = true);
    }
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

  /// Returns white or black depending on the luminance of [color].
  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Returns the color assigned to [userId].
  /// Prefers the user's stored colorValue from the database.
  /// Falls back to a deterministic color from [_presetColors] based on user index.
  Color _getUserColor(String userId) {
    final user = _users.firstWhere(
      (u) => u.id == userId,
      orElse: () => const UserModel(id: '', name: '', room: ''),
    );
    if (user.colorValue != null) {
      return Color(user.colorValue!);
    }
    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) return Colors.grey;
    return _presetColors[index % _presetColors.length];
  }

  /// Preset material colors offered in the color picker.
  static const List<Color> _presetColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
  ];

  /// Shows a color picker dialog for the given [targetUser].
  ///
  /// Colors already in use by other users are shown faded with an X overlay
  /// and cannot be selected.
  Future<void> _showColorPicker(UserModel targetUser) async {
    // Collect colors used by other users.
    final usedColors = <int>{};
    for (final user in _users) {
      if (user.id == targetUser.id) continue;
      final color = _getUserColor(user.id);
      usedColors.add(color.toARGB32());
    }

    final currentColor = _getUserColor(targetUser.id);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Color de ${targetUser.name}'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _presetColors)
                  _buildColorCircle(
                    color: color,
                    isSelected: color.toARGB32() == currentColor.toARGB32(),
                    isDisabled: usedColors.contains(color.toARGB32()),
                    onTap: usedColors.contains(color.toARGB32())
                        ? null
                        : () => Navigator.pop(ctx, color),
                    context: ctx,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      try {
        await SupabaseService.instance.updateUserColor(
          targetUser.id,
          picked.toARGB32(),
        );
        // Reload users to get updated color.
        final users = await SupabaseService.instance.getUsers();
        if (mounted) {
          setState(() => _users = users);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al guardar color: $e')));
        }
      }
    }
  }

  /// Builds a single color circle for the color picker dialog.
  ///
  /// [isDisabled] colors are shown at 30% opacity with an X icon and cannot
  /// be tapped. [isSelected] colors get a thick border.
  Widget _buildColorCircle({
    required Color color,
    required bool isSelected,
    required bool isDisabled,
    required VoidCallback? onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDisabled ? color.withValues(alpha: 0.3) : color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: isDisabled
            ? Icon(
                Icons.close,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              )
            : null,
      ),
    );
  }

  /// Returns the extension request for [schedule], or null if none.
  ///
  /// Only returns a request when [schedule] is part of one of the two
  /// implicated periods (the requester's period or the next user's period).
  ///
  /// 1. Exact match by [CleaningSchedule.id] (the anchor schedule).
  /// 2. Same-user consecutive schedules adjacent to the anchor (requester's
  ///    period).
  /// 3. For accepted requests, the next user's period: consecutive schedules
  ///    of the same user immediately following the requester's period.
  ExtensionRequest? _getRequestForSchedule(CleaningSchedule schedule) {
    for (final request in _extensionRequests) {
      // Find the anchor schedule referenced by the request.
      final anchor = _schedules
          .where((s) => s.id == request.scheduleId)
          .firstOrNull;
      if (anchor == null) continue;

      // Build the requester's period around the anchor (consecutive same-user
      // schedules).
      final requesterPeriodIds = _findPeriodScheduleIds(
        anchor,
        maxSize: SupabaseService.cleaningPeriodDays,
      );
      if (requesterPeriodIds.contains(schedule.id)) return request;

      // For accepted requests, also check the next user's period.
      if (request.status == ExtensionRequestStatus.accepted) {
        final nextUserPeriodIds = _findNextUserPeriodIds(
          requesterPeriodIds,
          request.nextUserId,
        );
        if (nextUserPeriodIds.contains(schedule.id)) return request;
      }
    }
    return null;
  }

  /// Returns the IDs of consecutive same-user schedules around [anchor].
  ///
  /// Walks backward and forward from the anchor in the sorted [_schedules]
  /// list, stopping when the user changes, dates are not consecutive, the
  /// result reaches [maxSize], or the date falls outside the allowed range.
  ///
  /// [maxSize] defaults to [SupabaseService.cleaningPeriodDays] to prevent
  /// over-collection when adjacent same-user periods have no gap (e.g. after
  /// a prórroga swap).
  Set<String> _findPeriodScheduleIds(
    CleaningSchedule anchor, {
    int? maxSize = SupabaseService.cleaningPeriodDays,
  }) {
    final sorted = List<CleaningSchedule>.from(_schedules)
      ..sort((a, b) => a.date.compareTo(b.date));
    final idx = sorted.indexWhere((s) => s.id == anchor.id);
    if (idx == -1) return {anchor.id};

    final anchorDate = DateTime(
      anchor.date.year,
      anchor.date.month,
      anchor.date.day,
    );

    // Define the maximum date range for this period.
    final maxDays = maxSize ?? 365; // fallback to large number if no cap
    final earliestDate = anchorDate.subtract(Duration(days: maxDays - 1));
    final latestDate = anchorDate.add(Duration(days: maxDays - 1));

    final ids = <String>{anchor.id};

    // Walk backward.
    for (var i = idx - 1; i >= 0; i--) {
      if (ids.length >= maxDays) break;
      if (sorted[i].userId != anchor.userId) break;
      final schedDate = DateTime(
        sorted[i].date.year,
        sorted[i].date.month,
        sorted[i].date.day,
      );
      if (schedDate.isBefore(earliestDate)) break;
      final diff = sorted[i + 1].date.difference(sorted[i].date).inDays;
      if (diff > 1) break;
      ids.add(sorted[i].id);
    }

    // Walk forward.
    for (var i = idx + 1; i < sorted.length; i++) {
      if (ids.length >= maxDays) break;
      if (sorted[i].userId != anchor.userId) break;
      final schedDate = DateTime(
        sorted[i].date.year,
        sorted[i].date.month,
        sorted[i].date.day,
      );
      if (schedDate.isAfter(latestDate)) break;
      final diff = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (diff > 1) break;
      ids.add(sorted[i].id);
    }

    return ids;
  }

  /// Returns the IDs of the next user's period that immediately follows the
  /// requester's period identified by [requesterPeriodIds].
  Set<String> _findNextUserPeriodIds(
    Set<String> requesterPeriodIds,
    String nextUserId,
  ) {
    final sorted = List<CleaningSchedule>.from(_schedules)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Find the last schedule in the requester's period.
    DateTime? lastRequesterDate;
    for (final s in sorted) {
      if (requesterPeriodIds.contains(s.id)) {
        final d = DateTime(s.date.year, s.date.month, s.date.day);
        if (lastRequesterDate == null || d.isAfter(lastRequesterDate)) {
          lastRequesterDate = d;
        }
      }
    }
    if (lastRequesterDate == null) return {};

    // Find the first schedule after the requester's period end.
    // After the swap, the next user's period now has requesterId as userId,
    // so we match by position (immediately after) rather than by userId.
    final ids = <String>{};
    CleaningSchedule? periodAnchor;
    for (final s in sorted) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (d.isAfter(lastRequesterDate) && !requesterPeriodIds.contains(s.id)) {
        periodAnchor = s;
        break;
      }
    }
    if (periodAnchor == null) return {};

    // Collect the consecutive same-user period starting at periodAnchor.
    final anchorIdx = sorted.indexWhere((s) => s.id == periodAnchor!.id);
    if (anchorIdx == -1) return {};

    final anchorDate = DateTime(
      periodAnchor.date.year,
      periodAnchor.date.month,
      periodAnchor.date.day,
    );
    final latestDate = anchorDate.add(
      Duration(days: SupabaseService.cleaningPeriodDays - 1),
    );

    ids.add(periodAnchor.id);
    for (var i = anchorIdx + 1; i < sorted.length; i++) {
      if (ids.length >= SupabaseService.cleaningPeriodDays) break;
      if (sorted[i].userId != periodAnchor.userId) break;
      final schedDate = DateTime(
        sorted[i].date.year,
        sorted[i].date.month,
        sorted[i].date.day,
      );
      if (schedDate.isAfter(latestDate)) break;
      final diff = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (diff > 1) break;
      ids.add(sorted[i].id);
    }

    return ids;
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

  /// Navigates to the schedule management screen and reloads on return.
  Future<void> _navigateToScheduleManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleManagementScreen()),
    );
    await _loadSchedules();
  }

  /// Returns a label describing the swap partner for an accepted [request].
  ///
  /// If [currentUserId] is the requester, they received the next user's dates,
  /// so we show the next user's name. Otherwise, the current user is the next
  /// user who received the requester's dates, so we show the requester's name.
  String _swapLabel(ExtensionRequest request, String currentUserId) {
    if (currentUserId == request.requesterId) {
      final nextUser = _users.firstWhere(
        (u) => u.id == request.nextUserId,
        orElse: () => const UserModel(id: '', name: '?', room: ''),
      );
      return 'con ${nextUser.name}';
    } else {
      final requester = _users.firstWhere(
        (u) => u.id == request.requesterId,
        orElse: () => const UserModel(id: '', name: '?', room: ''),
      );
      return 'con ${requester.name}';
    }
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
        final isSwapped =
            request != null &&
            request.status == ExtensionRequestStatus.accepted;

        final subtitleText = period.schedules.length > 1
            ? '${user.room} — Periodo del '
                  '${_formatDate(firstDate)} al '
                  '${_formatDate(lastDate)}'
            : '${user.room} — Periodo del ${_formatDate(firstDate)}';

        // Determine card color: own card gets user color at low opacity, others default.
        final Color? cardColor;
        if (isCurrentUser) {
          cardColor = _getUserColor(user.id).withValues(alpha: 0.15);
        } else {
          cardColor = null;
        }

        // Determine card shape: own card gets a user-color border, others default.
        final ShapeBorder? cardShape;
        if (isCurrentUser) {
          cardShape = ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(color: _getUserColor(user.id), width: 2),
          );
        } else {
          cardShape = null;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: cardColor,
          shape: cardShape,
          child: ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: isCurrentPeriod
                      ? _getUserColor(user.id)
                      : _getUserColor(user.id).withValues(alpha: 0.3),
                  foregroundColor: isCurrentPeriod
                      ? _contrastColor(_getUserColor(user.id))
                      : colorScheme.onSurfaceVariant,
                  child: Text(user.name[0]),
                ),
                if (isSwapped)
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.swap_horiz,
                        size: 12,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              user.name,
              style: isCurrentUser
                  ? TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitleText,
                  style: isCurrentUser
                      ? TextStyle(color: colorScheme.onPrimaryContainer)
                      : null,
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
                    label: Text(
                      'Cambiado — ${_swapLabel(request, period.user.id)}',
                    ),
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

    // Build user color map using custom or default colors.
    final userColors = <String, Color>{};
    for (final user in _users) {
      userColors[user.id] = _getUserColor(user.id);
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
            bool isSwapped = false;

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
              // Check if this cell is part of an accepted swap.
              final request = _getRequestForSchedule(schedule);
              isSwapped =
                  request != null &&
                  request.status == ExtensionRequestStatus.accepted;
            }

            // Determine border: today only.
            final Border? cellBorder;
            if (isToday) {
              cellBorder = Border.all(color: colorScheme.primary, width: 2);
            } else {
              cellBorder = null;
            }

            return Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: cellBorder,
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
                  if (isSwapped)
                    Positioned(
                      bottom: 1,
                      left: 1,
                      child: Icon(
                        Icons.swap_horiz,
                        size: 10,
                        color: colorScheme.secondary,
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final user in _users)
                  Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: widget.currentUser.isAdmin
                          ? () => _showColorPicker(user)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getUserColor(
                                  user.id,
                                ).withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                user.name,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              user.room,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.currentUser.isAdmin) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.color_lens,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
    } else if (_schedules.isEmpty) {
      // Empty state — centered message with button for admin.
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No hay fechas en el calendario', style: textTheme.bodyLarge),
            if (widget.currentUser.isAdmin) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _navigateToScheduleManagement,
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Gestionar Calendario'),
              ),
            ],
          ],
        ),
      );
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
          final lastDate = periods.last.schedules.last.date;
          final currentDate = schedule.date;
          final daysDiff =
              DateTime(currentDate.year, currentDate.month, currentDate.day)
                  .difference(
                    DateTime(lastDate.year, lastDate.month, lastDate.day),
                  )
                  .inDays;
          if (daysDiff <= 1) {
            periods.last.schedules.add(schedule);
          } else {
            periods.add(_PeriodEntry(schedules: [schedule], user: user));
          }
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
                    if (widget.currentUser.isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        tooltip: 'Gestionar calendario',
                        onPressed: _navigateToScheduleManagement,
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
            child: RefreshIndicator(
              onRefresh: _loadSchedules,
              child: _isGridView
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildGridView(schedules, colorScheme, textTheme),
                    )
                  : _buildListView(items, colorScheme, textTheme),
            ),
          ),
        ],
      );
    }

    return Scaffold(body: body);
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
