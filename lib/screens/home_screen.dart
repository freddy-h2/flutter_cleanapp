import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/core/notification_service.dart';
import 'package:flutter_cleanapp/core/realtime_service.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/admin/extension_requests_screen.dart';
import 'package:flutter_cleanapp/screens/admin/user_management_screen.dart';

/// Home screen that shows the current user's cleaning status for the week.
class HomeScreen extends StatefulWidget {
  /// The currently authenticated user.
  final UserModel currentUser;

  /// Callback invoked when the user taps "Ir a Actividades".
  final VoidCallback onNavigateToActivities;

  /// Creates a [HomeScreen].
  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.onNavigateToActivities,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CleaningSchedule> _schedules = [];
  bool _isLoading = true;
  bool _hasExistingRequest = false;
  bool _isRequestingExtension = false;

  /// Guard flag to avoid scheduling notifications on every reload.
  bool _notificationsScheduled = false;

  /// Number of pending extension requests (admin only).
  int _pendingExtensionCount = 0;

  /// Pending incoming extension request where this user is the next_user_id.
  ExtensionRequest? _incomingRequest;

  /// The user who sent the incoming extension request.
  UserModel? _requesterUser;

  /// Loading state for accept/reject buttons.
  bool _isResolvingRequest = false;

  /// ID of the last incoming request we already notified about, to avoid
  /// duplicate notifications on every reload.
  String? _notifiedIncomingRequestId;

  /// ID of the user's own pending outgoing request, tracked so we can detect
  /// when it transitions to accepted or rejected.
  String? _ownPendingRequestId;

  late final StreamSubscription<void> _schedulesRealtimeSub;
  late final StreamSubscription<void> _extensionsRealtimeSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _schedulesRealtimeSub = RealtimeService.instance.onSchedulesChanged.listen((
      _,
    ) {
      if (mounted) {
        _loadData();
      }
    });
    _extensionsRealtimeSub = RealtimeService.instance.onExtensionsChanged
        .listen((_) {
          if (mounted) {
            _loadData();
          }
        });
  }

  @override
  void dispose() {
    _schedulesRealtimeSub.cancel();
    _extensionsRealtimeSub.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await SupabaseService.instance.getSchedules();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }

      // Check for an existing pending extension request for the current period.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final periodStart = today.subtract(
        const Duration(days: SupabaseService.cleaningPeriodDays - 1),
      );
      CleaningSchedule? currentPeriodSchedule;
      for (final s in schedules) {
        final d = DateTime(s.date.year, s.date.month, s.date.day);
        if (!d.isBefore(periodStart) && !d.isAfter(today)) {
          currentPeriodSchedule = s;
          break;
        }
      }
      if (currentPeriodSchedule != null) {
        await _checkExistingRequest(currentPeriodSchedule);
      }

      // Schedule cleaning countdown notifications when the user is responsible
      // and the cleaning period is not yet completed.
      if (!_notificationsScheduled) {
        final currentUser = widget.currentUser;
        final isResponsible =
            currentPeriodSchedule != null &&
            currentPeriodSchedule.userId == currentUser.id &&
            !currentPeriodSchedule.isCompleted;

        if (isResponsible) {
          // Find the earliest date among the user's current-period schedules.
          final userPeriodSchedules =
              schedules
                  .where((s) => s.userId == currentUser.id)
                  .where((s) => !s.isCompleted)
                  .where((s) {
                    final d = DateTime(s.date.year, s.date.month, s.date.day);
                    return !d.isBefore(periodStart) && !d.isAfter(today);
                  })
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));

          final startDate = userPeriodSchedules.isNotEmpty
              ? userPeriodSchedules.first.date
              : today;

          // Fire-and-forget: do not block the UI.
          NotificationService.instance.scheduleCleaningCountdown(
            startDate: startDate,
          );
          _notificationsScheduled = true;
        }
      }

      // Check for an incoming extension request where this user is next_user_id.
      await _loadIncomingRequest(schedules);

      // Load pending extension count for admin users.
      if (widget.currentUser.isAdmin) {
        try {
          final pending = await SupabaseService.instance
              .getPendingExtensionRequests();
          if (mounted) {
            setState(() => _pendingExtensionCount = pending.length);
          }
        } catch (_) {
          // Non-fatal — leave _pendingExtensionCount as 0.
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
    }
  }

  /// Checks whether a pending extension request already exists for [schedule].
  Future<void> _checkExistingRequest(CleaningSchedule schedule) async {
    try {
      final existing = await SupabaseService.instance
          .getPendingRequestForSchedule(schedule.id);
      if (mounted) {
        setState(() {
          _hasExistingRequest = existing != null;
        });
      }
    } catch (_) {
      // Non-fatal — leave _hasExistingRequest as false.
    }
  }

  /// Loads the incoming extension request (if any) where the current user is
  /// the next_user_id, and fetches the requester's user info.
  ///
  /// Also checks whether the user's own outgoing request was accepted or
  /// rejected and fires a local notification accordingly.
  Future<void> _loadIncomingRequest(List<CleaningSchedule> schedules) async {
    try {
      final currentUser = widget.currentUser;
      final requests = await SupabaseService.instance
          .getExtensionRequestsForUser(currentUser.id);

      // ── Detect accept/reject of the user's own outgoing request ──────────
      if (_ownPendingRequestId != null) {
        final ownRequest = requests
            .where((r) => r.id == _ownPendingRequestId)
            .firstOrNull;
        if (ownRequest != null) {
          if (ownRequest.status == ExtensionRequestStatus.accepted) {
            NotificationService.instance.notifyProrrogaAccepted();
            _ownPendingRequestId = null;
          } else if (ownRequest.status == ExtensionRequestStatus.rejected) {
            NotificationService.instance.notifyProrrogaRejected();
            _ownPendingRequestId = null;
          }
        }
      }

      // Track the user's own new pending outgoing request.
      final ownPending = requests
          .where(
            (r) =>
                r.status == ExtensionRequestStatus.pending &&
                r.requesterId == currentUser.id,
          )
          .firstOrNull;
      if (ownPending != null && _ownPendingRequestId == null) {
        _ownPendingRequestId = ownPending.id;
      }

      // ── Detect new incoming request ───────────────────────────────────────
      final incoming = requests
          .where(
            (r) =>
                r.status == ExtensionRequestStatus.pending &&
                r.nextUserId == currentUser.id,
          )
          .firstOrNull;

      if (incoming == null) {
        if (mounted) {
          setState(() {
            _incomingRequest = null;
            _requesterUser = null;
          });
        }
        return;
      }

      // Try to find the requester in the already-loaded schedules' user list,
      // otherwise fetch all users.
      UserModel? requester;
      final users = await SupabaseService.instance.getUsers();
      requester = users.where((u) => u.id == incoming.requesterId).firstOrNull;

      // Notify only once per unique incoming request.
      if (incoming.id != _notifiedIncomingRequestId) {
        _notifiedIncomingRequestId = incoming.id;
        NotificationService.instance.notifyProrrogaReceived(
          requesterName: requester?.name ?? 'Un vecino',
        );
      }

      if (mounted) {
        setState(() {
          _incomingRequest = incoming;
          _requesterUser = requester;
        });
      }
    } catch (_) {
      // Non-fatal — leave _incomingRequest as null.
    }
  }

  /// Accepts the incoming extension request.
  Future<void> _acceptRequest() async {
    setState(() => _isResolvingRequest = true);
    try {
      await SupabaseService.instance.acceptExtensionRequest(
        _incomingRequest!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Prórroga aceptada. Ahora eres el responsable esta semana.',
            ),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al aceptar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isResolvingRequest = false);
      }
    }
  }

  /// Rejects the incoming extension request.
  Future<void> _rejectRequest() async {
    setState(() => _isResolvingRequest = true);
    try {
      await SupabaseService.instance.rejectExtensionRequest(
        _incomingRequest!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prórroga rechazada')));
        setState(() {
          _incomingRequest = null;
          _isResolvingRequest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al rechazar: $e')));
        setState(() => _isResolvingRequest = false);
      }
    }
  }

  /// Sends an extension request for the current period's schedule.
  Future<void> _requestExtension() async {
    setState(() => _isRequestingExtension = true);

    try {
      final currentUser = widget.currentUser;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final periodStart = today.subtract(
        const Duration(days: SupabaseService.cleaningPeriodDays - 1),
      );

      // Identify the current period's schedule for this user.
      CleaningSchedule? currentPeriodSchedule;
      for (final s in _schedules) {
        final d = DateTime(s.date.year, s.date.month, s.date.day);
        if (!d.isBefore(periodStart) && !d.isAfter(today)) {
          currentPeriodSchedule = s;
          break;
        }
      }

      if (currentPeriodSchedule == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay siguiente persona en el calendario para solicitar prórroga',
              ),
            ),
          );
        }
        return;
      }

      // Find the next schedule after the current period where userId differs.
      CleaningSchedule? nextSchedule;
      for (final s in _schedules) {
        if (s.userId != currentUser.id &&
            s.date.isAfter(currentPeriodSchedule.date)) {
          if (nextSchedule == null || s.date.isBefore(nextSchedule.date)) {
            nextSchedule = s;
          }
        }
      }

      if (nextSchedule == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay siguiente persona en el calendario para solicitar prórroga',
              ),
            ),
          );
        }
        return;
      }

      await SupabaseService.instance.createExtensionRequest(
        scheduleId: currentPeriodSchedule.id,
        requesterId: currentUser.id,
        nextUserId: nextSchedule.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de prórroga enviada')),
        );
        setState(() => _hasExistingRequest = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingExtension = false);
      }
    }
  }

  /// Formats a [DateTime] as "dd/MM/yyyy".
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  /// Builds the notification banner for an incoming extension request.
  Widget _buildExtensionBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: colorScheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Solicitud de Prórroga',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_requesterUser!.name} (${_requesterUser!.room}) solicita que'
              ' tomes su turno de aseo esta semana',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar'),
                  onPressed: _isResolvingRequest ? null : _acceptRequest,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                  onPressed: _isResolvingRequest ? null : _rejectRequest,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final currentUser = widget.currentUser;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodStart = today.subtract(
      const Duration(days: SupabaseService.cleaningPeriodDays - 1),
    );
    final periodEnd = today;

    // Find all schedule entries within the current 3-day period for this user.
    final currentPeriodSchedules = _schedules.where((s) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      return !d.isBefore(periodStart) && !d.isAfter(periodEnd);
    }).toList();

    // The first schedule in the current period (for extension request lookup).
    final CleaningSchedule? currentPeriodSchedule =
        currentPeriodSchedules.isNotEmpty ? currentPeriodSchedules.first : null;

    // Determine if the current user is responsible in the current period.
    final bool isResponsible =
        currentPeriodSchedule != null &&
        currentPeriodSchedule.userId == currentUser.id &&
        !currentPeriodSchedule.isCompleted;

    // Compute the display dates for the current period.
    final DateTime displayPeriodStart = periodStart;
    final DateTime displayPeriodEnd = periodStart.add(
      const Duration(days: SupabaseService.cleaningPeriodDays - 1),
    );

    /// Admin panel cards shown only to admin users.
    Widget adminCard() => Column(
      children: [
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.admin_panel_settings,
              color: colorScheme.primary,
            ),
            title: const Text('Panel de Administración'),
            subtitle: const Text('Gestionar usuarios del edificio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.swap_horiz, color: colorScheme.primary),
            title: const Text('Gestionar Prórrogas'),
            subtitle: const Text('Ver y resolver solicitudes de prórroga'),
            trailing: _pendingExtensionCount > 0
                ? Badge(
                    label: Text('$_pendingExtensionCount'),
                    child: const Icon(Icons.chevron_right),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExtensionRequestsScreen(),
              ),
            ),
          ),
        ),
      ],
    );

    if (isResponsible) {
      // State A — user has cleaning duty this week.
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_incomingRequest != null) ...[
              _buildExtensionBanner(),
              const SizedBox(height: 16),
            ],
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
              'Periodo de aseo: ${_formatDate(displayPeriodStart)} - ${_formatDate(displayPeriodEnd)}',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(currentUser.name),
                subtitle: Text(currentUser.room),
              ),
            ),
            if (currentUser.isAdmin) adminCard(),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.checklist),
              label: const Text('Ir a Actividades'),
              onPressed: widget.onNavigateToActivities,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_send),
              label: Text(
                _hasExistingRequest ? 'Prórroga solicitada' : 'Pedir Prórroga',
              ),
              onPressed: (_hasExistingRequest || _isRequestingExtension)
                  ? null
                  : _requestExtension,
            ),
          ],
        ),
      );
    }

    // State B — user is free this period; find next turn.
    CleaningSchedule? nextSchedule;
    for (final s in _schedules) {
      if (s.userId == currentUser.id && s.date.isAfter(today)) {
        if (nextSchedule == null || s.date.isBefore(nextSchedule.date)) {
          nextSchedule = s;
        }
      }
    }

    final String nextDateText = nextSchedule != null
        ? _formatDate(nextSchedule.date)
        : '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_incomingRequest != null) ...[
            _buildExtensionBanner(),
            const SizedBox(height: 16),
          ],
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
            'Tu próximo turno inicia el $nextDateText',
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(currentUser.name),
              subtitle: Text(currentUser.room),
            ),
          ),
          if (currentUser.isAdmin) adminCard(),
        ],
      ),
    );
  }
}
