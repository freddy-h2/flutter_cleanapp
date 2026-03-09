import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Admin-only screen for viewing and managing all prórroga (extension) requests.
///
/// Shows all extension requests (pending, accepted, rejected) and allows
/// admins to accept or reject pending ones.
class ExtensionRequestsScreen extends StatefulWidget {
  /// Creates an [ExtensionRequestsScreen].
  const ExtensionRequestsScreen({super.key});

  @override
  State<ExtensionRequestsScreen> createState() =>
      _ExtensionRequestsScreenState();
}

class _ExtensionRequestsScreenState extends State<ExtensionRequestsScreen> {
  List<ExtensionRequest> _requests = [];
  List<UserModel> _users = [];
  List<CleaningSchedule> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.instance.getAllExtensionRequests(),
        SupabaseService.instance.getUsers(),
        SupabaseService.instance.getSchedules(),
      ]);
      if (mounted) {
        setState(() {
          _requests = results[0] as List<ExtensionRequest>;
          _users = results[1] as List<UserModel>;
          _schedules = results[2] as List<CleaningSchedule>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar solicitudes: $e')),
        );
      }
    }
  }

  String _userName(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).name;
    } catch (_) {
      return '?';
    }
  }

  String _userRoom(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).room;
    } catch (_) {
      return '';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _periodDates(String scheduleId) {
    final anchor = _schedules.where((s) => s.id == scheduleId).firstOrNull;
    if (anchor == null) return '?';

    final sorted = List<CleaningSchedule>.from(_schedules)
      ..sort((a, b) => a.date.compareTo(b.date));
    final anchorIdx = sorted.indexWhere((s) => s.id == scheduleId);
    if (anchorIdx == -1) return _formatDate(anchor.date);

    final userId = anchor.userId;
    var startIdx = anchorIdx;
    var endIdx = anchorIdx;

    // Walk backward
    while (startIdx > 0 &&
        sorted[startIdx - 1].userId == userId &&
        sorted[startIdx].date.difference(sorted[startIdx - 1].date).inDays <=
            1) {
      startIdx--;
    }
    // Walk forward
    while (endIdx < sorted.length - 1 &&
        sorted[endIdx + 1].userId == userId &&
        sorted[endIdx + 1].date.difference(sorted[endIdx].date).inDays <= 1) {
      endIdx++;
    }

    final firstDate = sorted[startIdx].date;
    final lastDate = sorted[endIdx].date;
    if (firstDate == lastDate) return _formatDate(firstDate);
    return '${_formatDate(firstDate)} al ${_formatDate(lastDate)}';
  }

  Color _statusColor(ExtensionRequestStatus status) => switch (status) {
    ExtensionRequestStatus.pending => Colors.orange,
    ExtensionRequestStatus.accepted => Colors.green,
    ExtensionRequestStatus.rejected => Colors.red,
  };

  Future<void> _accept(ExtensionRequest request) async {
    try {
      await SupabaseService.instance.acceptExtensionRequest(request.id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar solicitud: $e')),
        );
      }
    }
  }

  Future<void> _reject(ExtensionRequest request) async {
    try {
      await SupabaseService.instance.rejectExtensionRequest(request.id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar solicitud: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Gestionar Prórrogas'),
        backgroundColor: CupertinoColors.systemBackground.withValues(
          alpha: 0.8,
        ),
        border: null,
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
            ? const Center(child: Text('No hay solicitudes de prórroga.'))
            : ListView.builder(
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  final requesterName = _userName(request.requesterId);
                  final nextUserName = _userName(request.nextUserId);
                  final statusColor = _statusColor(request.status);

                  final leadingIcon = switch (request.status) {
                    ExtensionRequestStatus.pending => Icons.schedule,
                    ExtensionRequestStatus.accepted => Icons.check,
                    ExtensionRequestStatus.rejected => Icons.close,
                  };

                  Widget? trailing;
                  if (request.isPending) {
                    trailing = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          color: Colors.green,
                          tooltip: 'Aceptar',
                          onPressed: () => _accept(request),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Colors.red,
                          tooltip: 'Rechazar',
                          onPressed: () => _reject(request),
                        ),
                      ],
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        foregroundColor: statusColor,
                        child: Icon(leadingIcon),
                      ),
                      title: Text('$requesterName → $nextUserName'),
                      subtitle: Text(
                        'Periodo: ${_periodDates(request.scheduleId)}'
                        ' · ${request.status.label}'
                        '${_userRoom(request.requesterId).isNotEmpty ? '\n${_userRoom(request.requesterId)}' : ''}',
                      ),
                      trailing: trailing,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
