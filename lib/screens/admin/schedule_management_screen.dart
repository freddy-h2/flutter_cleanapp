import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/data/supabase_service.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Admin screen for managing cleaning schedules.
///
/// Allows admins to view, add, edit, and delete schedule entries.
class ScheduleManagementScreen extends StatefulWidget {
  /// Creates a [ScheduleManagementScreen].
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  List<CleaningSchedule> _schedules = [];
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await SupabaseService.instance.getSchedules();
      final users = await SupabaseService.instance.getUsers();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _users = users;
          _isLoading = false;
        });
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

  String _userName(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).name;
    } catch (_) {
      return userId;
    }
  }

  String _userApartment(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId).apartment;
    } catch (_) {
      return '';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  Future<void> _showAddDialog() async {
    UserModel? selectedUser = _users.isNotEmpty ? _users.first : null;
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar fecha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<UserModel>(
                    initialValue: selectedUser,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    items: _users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text('${u.name} — ${u.apartment}'),
                          ),
                        )
                        .toList(),
                    onChanged: (u) => setDialogState(() => selectedUser = u),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fecha: ${_formatDate(selectedDate)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedUser == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await SupabaseService.instance.createSchedule(
                              CleaningSchedule(
                                id: '',
                                userId: selectedUser!.id,
                                date: selectedDate,
                              ),
                            );
                            await _loadData();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al agregar: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(CleaningSchedule schedule) async {
    UserModel? selectedUser;
    try {
      selectedUser = _users.firstWhere((u) => u.id == schedule.userId);
    } catch (_) {
      selectedUser = _users.isNotEmpty ? _users.first : null;
    }
    DateTime selectedDate = schedule.date;
    bool isCompleted = schedule.isCompleted;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Editar fecha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<UserModel>(
                    initialValue: selectedUser,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                    items: _users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text('${u.name} — ${u.apartment}'),
                          ),
                        )
                        .toList(),
                    onChanged: (u) => setDialogState(() => selectedUser = u),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fecha: ${_formatDate(selectedDate)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Completado'),
                    value: isCompleted,
                    onChanged: (v) =>
                        setDialogState(() => isCompleted = v ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedUser == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await SupabaseService.instance.updateSchedule(
                              schedule.id,
                              date: selectedDate,
                              userId: selectedUser!.id,
                              isCompleted: isCompleted,
                            );
                            await _loadData();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(CleaningSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: Text(
          '¿Eliminar la entrada de ${_userName(schedule.userId)} '
          'del ${_formatDate(schedule.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.instance.deleteSchedule(schedule.id);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Calendario'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Agregar fecha',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
          ? const Center(child: Text('No hay entradas en el calendario.'))
          : ListView.builder(
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(_userName(schedule.userId)),
                    subtitle: Text(
                      '${_userApartment(schedule.userId)} · '
                      '${_formatDate(schedule.date)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          schedule.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: schedule.isCompleted ? Colors.green : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Editar',
                          onPressed: () => _showEditDialog(schedule),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmDelete(schedule),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
